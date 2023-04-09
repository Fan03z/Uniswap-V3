// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./lib/Tick.sol";
import "./lib/TickMath.sol";
import "./lib/TickBitmap.sol";
import "./lib/Position.sol";
import "./lib/Math.sol";
import "./lib/SwapMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";

contract UniswapV3Pool {
  using Tick for mapping(int24 => Tick.Info);
  using TickBitmap for mapping(int16 => uint256);
  using Position for mapping(bytes32 => Position.Info);
  using Position for Position.Info;

  event Mint(
    address sender,
    address indexed owner,
    int24 indexed tickLower,
    int24 indexed tickUpper,
    uint128 amount,
    uint256 amount0,
    uint256 amount1
  );

  event Swap(
    address indexed sender,
    address indexed recipient,
    int256 amount0,
    int256 amount1,
    uint160 sqrtPriceX96,
    uint128 liquidity,
    int24 tick
  );

  // 用于检查指定tick是否在合法范围内
  error InvalidTickRange();
  // 确保希望提供的流动性不为0
  error ZeroLiquidity();
  // token转入池子失败
  error InsufficientInputAmount();

  uint128 public liquidity;

  int24 internal constant MIN_TICK = -887272;
  int24 internal constant MAX_TICK = -MIN_TICK;

  // 池子代币,设置为不可变变量
  address public immutable token0;
  address public immutable token1;

  mapping(int24 => Tick.Info) public ticks;
  mapping(int16 => uint256) public tickBitmap;
  mapping(bytes32 => Position.Info) public positions;

  struct Slot0 {
    // 当前 sqrt(p)
    uint160 sqrtPriceX96;
    // 当前 tick
    int24 tick;
  }

  struct CallbackData {
    address token0;
    address token1;
    address payer;
  }

  struct SwapState {
    uint256 amoutSpecifiedRemaining;
    uint256 amountCalculated;
    uint160 sqrtPriceX96;
    int24 tick;
  }

  struct StepState {
    uint160 sqrtPriceStartX96;
    int24 nextTick;
    uint160 sqrtPriceNextX96;
    uint256 amountIn;
    uint256 amountOut;
  }

  Slot0 public slot0;

  constructor(address token0_, address token1_, uint160 sqrtPriceX96, int24 tick) {
    token0 = token0_;
    token1 = token1_;

    slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick});
  }

  /**
   * @dev 在Uniswap V2中,提供流动性的方法为mint(),因为V2池子会给予LP-token作为提供流动性的交换
   *      但在V3中,虽然没有这种行为了,但还是保留了mint()方法
   * @param owner token 所有者的地址,用来识别是谁提供的流动性
   * @param upperTick tick上下界,设置价格区间边界
   * @param lowerTick tick下界
   * @param amount 期望提供的流动性数量
   * @return amount0
   * @return amount1
   */
  function mint(
    address owner,
    int24 upperTick,
    int24 lowerTick,
    uint128 amount,
    bytes calldata data
  ) external returns (uint256 amount0, uint256 amount1) {
    if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick > MAX_TICK) revert InvalidTickRange();
    if (amount == 0) revert ZeroLiquidity();

    // 更新池子流动性
    bool flippedUpper = ticks.update(upperTick, amount);
    bool flippedLower = ticks.update(lowerTick, amount);

    if (flippedUpper) {
      tickBitmap.flipTick(upperTick, 1);
    }

    if (flippedLower) {
      tickBitmap.flipTick(lowerTick, 1);
    }

    // 获得指定账户提供的流动性值
    Position.Info storage position = positions.get(owner, lowerTick, upperTick);

    // 更新账户流动性
    position.update(amount);

    Slot0 memory slot0_ = slot0;

    amount0 = Math.calcAmount0Delta(TickMath.getSqrtRatioAtTick(slot0_.tick), TickMath.getSqrtRatioAtTick(upperTick), amount);

    amount1 = Math.calcAmount1Delta(TickMath.getSqrtRatioAtTick(slot0_.tick), TickMath.getSqrtRatioAtTick(lowerTick), amount);

    // 在此合约中,记录流动性变化
    liquidity += uint128(amount);

    uint256 balance0Before;
    uint256 balance1Before;
    if (amount0 > 0) balance0Before = balance0();
    if (amount1 > 0) balance1Before = balance1();
    // uniswapV3MintCallback 函数的实现是由调用者(即在调用 uniswapV3MintCallback 函数时传递的合约)来提供的
    // 且普通的账户地址无法调用,得要合约地址
    // 注意: 要将msg.sender转换为IUniswapV3MintCallback接口类型,这样才能调用其函数
    IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);

    if (amount0 > 0 && balance0Before + amount0 > balance0()) {
      revert InsufficientInputAmount();
    }
    if (amount1 > 0 && balance1Before + amount1 > balance1()) {
      revert InsufficientInputAmount();
    }

    emit Mint(msg.sender, owner, lowerTick, upperTick, amount, amount0, amount1);
  }

  /**
   * @dev 在一对交易对中进行交易,并更新相应价格和流动性
   * @param recipient token接收者地址
   * @param zeroForOne 为true时,token0 -> token1,为false时,token1 -> token0
   * @param amountSpecified 用户期望交易的数量
   * @return amount0
   * @return amount1
   */
  function swap(
    address recipient,
    bool zeroForOne,
    uint256 amountSpecified,
    bytes calldata data
  ) public returns (int256 amount0, int256 amount1) {
    Slot0 memory slot0_ = slot0;

    SwapState state = SwapState({
      amoutSpecifiedRemaining: amountSpecified,
      amountCalculated: 0,
      sqrtPriceX96: slot0_.sqrtPriceX96,
      tick: slot0_.tick
    });

    while (state.amountSpecifiedRemaining > 0) {
      StepState memory step;

      step.sqrtPriceStartX96 = state.sqrtPriceX96;

      (step.nextTick, ) = tickBitmap.nextInitializedTickWithinOneWord(state.tick, 1, zeroForOne);

      step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.nextTick);

      (state.sqrtPriceX96, step.amountIn, step.amountOut) = SwapMath.computeSwapStep(
        step.sqrtPriceStartX96,
        step.sqrtPriceNextX96,
        liquidity,
        state.amountSpecifiedRemaining
      );

      state.amountSpecifiedRemaining -= step.amountIn;
      state.amountCalculated += step.amountOut;
      state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
    }

    if (state.tick != slot0_.tick) {
      (slot0.tick, slot0.sqrtPriceX96) = (state.tick, state.sqrtPriceX96);
    }

    (amount0, amount1) = zeroForOne
      ? (int256(amountSpecified - state.amountSpecifiedRemaining), -int256(state.amountCalculated))
      : (-int256(state.amountCalculated), int256(amountSpecified - state.amountSpecifiedRemaining));

    if (zeroForOne) {
      IERC20(token1).transfer(recipient, uint256(-amount1));

      uint256 balance0Before = balance0();
      IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
      if (balance0Before + uint256(amount0) > balance0()) {
        revert InsufficientInputAmount();
      }
    } else {
      IERC20(token1).transfer(recipient, uint256(-amount0));

      uint256 balance1Before = balance1();
      IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
      if (balance1Before + uint256(amount1) > balance1()) {
        revert InsufficientInputAmount();
      }
    }

    emit Swap(msg.sender, recipient, amount0, amount1, slot0.sqrtPriceX96, liquidity, slot0.tick);
  }

  ////////////////////////////////////
  /* 内部函数,用于获得合约中token的余额 */
  ////////////////////////////////////

  function balance0() internal returns (uint256 balance) {
    balance = IERC20(token0).balanceOf(address(this));
  }

  function balance1() internal returns (uint256 balance) {
    balance = IERC20(token1).balanceOf(address(this));
  }
}
