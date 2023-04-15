// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./lib/FixedPoint128.sol";
import "./lib/Tick.sol";
import "./lib/TickMath.sol";
import "./lib/TickBitmap.sol";
import "./lib/Position.sol";
import "./lib/Math.sol";
import "./lib/Oracle.sol";
import "./lib/SwapMath.sol";
import "./lib/LiquidityMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV3PoolDeployer.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";
import "./interfaces/IUniswapV3FlashCallback.sol";

contract UniswapV3Pool {
  using Oracle for Oracle.Observation[65535];
  using Tick for mapping(int24 => Tick.Info);
  using TickBitmap for mapping(int16 => uint256);
  using Position for mapping(bytes32 => Position.Info);
  using Position for Position.Info;

  // 检查相应代币对是否已初始化
  error AlreadyInitialized();
  // 用于检查指定tick是否在合法范围内
  error InvalidTickRange();
  // 确保希望提供的流动性不为0
  error ZeroLiquidity();
  // token转入池子失败
  error InsufficientInputAmount();
  // 提示池子流动性为0
  error NotEnoughLiquidity();
  // 加入滑点保护
  error InvalidPriceLimit();
  // 闪电贷价格支付不起
  error FlashLoanNotPaid();

  event Mint(
    address sender,
    address indexed owner,
    int24 indexed tickLower,
    int24 indexed tickUpper,
    uint128 amount,
    uint256 amount0,
    uint256 amount1
  );

  event Burn(
    address indexed owner,
    int24 indexed tickLower,
    int24 indexed tickUpper,
    uint128 amount,
    uint256 amount0,
    uint256 amount1
  );

  event Collect(
    address indexed owner,
    address recipient,
    int24 indexed tickLower,
    int24 indexed tickUpper,
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

  event Flash(address indexed recipient, uint256 amount0, uint256 amount1);

  event IncreaseObservationCardinalityNext(uint16 observationCardinalityNextOld, uint16 observationCardinalityNextNew);

  // Pool parameters
  address public immutable factory;
  address public immutable token0;
  address public immutable token1;
  uint24 public immutable tickSpacing;
  uint24 public immutable fee;

  uint256 public feeGrowthGlobal0X128;
  uint256 public feeGrowthGlobal1X128;

  uint128 public liquidity;

  mapping(int24 => Tick.Info) public ticks;
  mapping(int16 => uint256) public tickBitmap;
  mapping(bytes32 => Position.Info) public positions;
  Oracle.Observation[65535] public observations;

  struct Slot0 {
    uint160 sqrtPriceX96;
    int24 tick;
    uint16 observationIndex;
    uint16 observationCardinality;
    uint16 observationCardinalityNext;
  }

  struct SwapState {
    uint256 amountSpecifiedRemaining;
    uint256 amountCalculated;
    uint160 sqrtPriceX96;
    int24 tick;
    uint256 feeGrowthGlobalX128;
    uint128 liquidity;
  }

  struct StepState {
    uint160 sqrtPriceStartX96;
    int24 nextTick;
    bool initialized;
    uint160 sqrtPriceNextX96;
    uint256 amountIn;
    uint256 amountOut;
    uint256 feeAmount;
  }

  struct ModifyPositionParams {
    address owner;
    int24 lowerTick;
    int24 upperTick;
    int128 liquidityDelta;
  }

  Slot0 public slot0;

  constructor() {
    (factory, token0, token1, tickSpacing, fee) = IUniswapV3PoolDeployer(msg.sender).parameters();
  }

  function initialize(uint160 sqrtPriceX96) public {
    if (slot0.sqrtPriceX96 != 0) revert AlreadyInitialized();

    int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

    (uint16 cardinality, uint16 cardinalityNext) = observations.initialize(_blockTimestamp());

    slot0 = Slot0({
      sqrtPriceX96: sqrtPriceX96,
      tick: tick,
      observationIndex: 0,
      observationCardinality: cardinality,
      observationCardinalityNext: cardinalityNext
    });
  }

  function _modifyPosition(
    ModifyPositionParams memory params
  ) internal returns (Position.Info storage position, int256 amount0, int256 amount1) {
    Slot0 memory slot0_ = slot0;
    uint256 feeGrowthGlobal0X128_ = feeGrowthGlobal0X128;
    uint256 feeGrowthGlobal1X128_ = feeGrowthGlobal1X128;

    position = positions.get(params.owner, params.lowerTick, params.upperTick);

    bool flippedLower = ticks.update(
      params.lowerTick,
      slot0_.tick,
      int128(params.liquidityDelta),
      feeGrowthGlobal0X128_,
      feeGrowthGlobal1X128_,
      false
    );
    bool flippedUpper = ticks.update(
      params.upperTick,
      slot0_.tick,
      int128(params.liquidityDelta),
      feeGrowthGlobal0X128_,
      feeGrowthGlobal1X128_,
      true
    );

    if (flippedLower) tickBitmap.flipTick(params.lowerTick, int24(tickSpacing));
    if (flippedUpper) tickBitmap.flipTick(params.upperTick, int24(tickSpacing));

    (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = ticks.getFeeGrowthInside(
      params.lowerTick,
      params.upperTick,
      slot0_.tick,
      feeGrowthGlobal0X128_,
      feeGrowthGlobal1X128_
    );

    position.update(params.liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128);

    if (slot0_.tick < params.lowerTick) {
      amount0 = Math.calcAmount0Delta(
        TickMath.getSqrtRatioAtTick(params.lowerTick),
        TickMath.getSqrtRatioAtTick(params.upperTick),
        params.liquidityDelta
      );
    } else if (slot0_.tick < params.upperTick) {
      amount0 = Math.calcAmount0Delta(slot0_.sqrtPriceX96, TickMath.getSqrtRatioAtTick(params.upperTick), params.liquidityDelta);
      amount1 = Math.calcAmount1Delta(TickMath.getSqrtRatioAtTick(params.lowerTick), slot0_.sqrtPriceX96, params.liquidityDelta);
      liquidity = LiquidityMath.addLiquidity(liquidity, params.liquidityDelta);
    } else {
      amount1 = Math.calcAmount1Delta(
        TickMath.getSqrtRatioAtTick(params.lowerTick),
        TickMath.getSqrtRatioAtTick(params.upperTick),
        params.liquidityDelta
      );
    }
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
    if (lowerTick >= upperTick || lowerTick < TickMath.MIN_TICK || upperTick > TickMath.MAX_TICK) revert InvalidTickRange();
    if (amount == 0) revert ZeroLiquidity();

    (, int256 amount0Int, int256 amount1Int) = _modifyPosition(
      ModifyPositionParams({owner: owner, lowerTick: lowerTick, upperTick: upperTick, liquidityDelta: int128(amount)})
    );

    amount0 = uint256(amount0Int);
    amount1 = uint256(amount1Int);

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

  /// @dev 从池子中移除流动性(移出的流动性代币提取实现是在collect())
  function burn(int24 lowerTick, int24 upperTick, uint128 amount) public returns (uint256 amount0, uint256 amount1) {
    (Position.Info storage position, int256 amount0Int, int256 amount1Int) = _modifyPosition(
      ModifyPositionParams({owner: msg.sender, lowerTick: lowerTick, upperTick: upperTick, liquidityDelta: -(int128(amount))})
    );

    amount0 = uint256(-amount0Int);
    amount1 = uint256(-amount1Int);

    if (amount0 > 0 || amount1 > 0) {
      (position.tokensOwed0, position.tokensOwed1) = (
        position.tokensOwed0 + uint128(amount0),
        position.tokensOwed1 + uint128(amount1)
      );
    }

    emit Burn(msg.sender, lowerTick, upperTick, amount, amount0, amount1);
  }

  /// @dev 提取相应position中未转换为流动性的代币
  function collect(
    address recipient,
    int24 lowerTick,
    int24 upperTick,
    uint128 amount0Requested,
    uint128 amount1Requested
  ) public returns (uint128 amount0, uint128 amount1) {
    Position.Info memory position = positions.get(msg.sender, lowerTick, upperTick);

    amount0 = amount0Requested > position.tokensOwed0 ? position.tokensOwed0 : amount0Requested;
    amount1 = amount1Requested > position.tokensOwed1 ? position.tokensOwed1 : amount1Requested;

    if (amount0 > 0) {
      position.tokensOwed0 -= amount0;
      IERC20(token0).transfer(recipient, amount0);
    }

    if (amount1 > 0) {
      position.tokensOwed1 -= amount1;
      IERC20(token1).transfer(recipient, amount1);
    }

    emit Collect(msg.sender, recipient, lowerTick, upperTick, amount0, amount1);
  }

  /**
   * @dev 在一对交易对中进行交易,并更新相应价格和流动性
   * @param recipient token接收者地址
   * @param zeroForOne 为true时,token0 -> token1,为false时,token1 -> token0
   * @param amountSpecified 用户期望交易的数量
   * @param sqrtPriceLimitX96 成交价格限制,防滑点
   * @return amount0
   * @return amount1
   */
  function swap(
    address recipient,
    bool zeroForOne,
    uint256 amountSpecified,
    uint160 sqrtPriceLimitX96,
    bytes calldata data
  ) public returns (int256 amount0, int256 amount1) {
    Slot0 memory slot0_ = slot0;
    uint128 liquidity_ = liquidity;

    if (
      zeroForOne
        ? sqrtPriceLimitX96 > slot0_.sqrtPriceX96 || sqrtPriceLimitX96 < TickMath.MIN_SQRT_RATIO
        : sqrtPriceLimitX96 < slot0_.sqrtPriceX96 || sqrtPriceLimitX96 > TickMath.MAX_SQRT_RATIO
    ) {
      revert InvalidPriceLimit();
    }

    SwapState memory state = SwapState({
      amountSpecifiedRemaining: amountSpecified,
      amountCalculated: 0,
      sqrtPriceX96: slot0_.sqrtPriceX96,
      tick: slot0_.tick,
      feeGrowthGlobalX128: zeroForOne ? feeGrowthGlobal0X128 : feeGrowthGlobal1X128,
      liquidity: liquidity_
    });

    while (state.amountSpecifiedRemaining > 0 && state.sqrtPriceX96 != sqrtPriceLimitX96) {
      StepState memory step;

      step.sqrtPriceStartX96 = state.sqrtPriceX96;

      (step.nextTick, ) = tickBitmap.nextInitializedTickWithinOneWord(state.tick, 1, zeroForOne);

      step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.nextTick);

      (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
        step.sqrtPriceStartX96,
        (zeroForOne ? step.sqrtPriceNextX96 < sqrtPriceLimitX96 : step.sqrtPriceNextX96 > sqrtPriceLimitX96)
          ? sqrtPriceLimitX96
          : step.sqrtPriceNextX96,
        state.liquidity,
        state.amountSpecifiedRemaining,
        fee
      );

      state.amountSpecifiedRemaining -= step.amountIn + step.feeAmount;
      state.amountCalculated += step.amountOut;

      if (state.liquidity > 0) {
        state.feeGrowthGlobalX128 += mulDiv(step.feeAmount, FixedPoint128.Q128, state.liquidity);
      }

      if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
        int128 liquidityDelta = ticks.cross(
          step.nextTick,
          (zeroForOne ? state.feeGrowthGlobalX128 : feeGrowthGlobal0X128),
          (zeroForOne ? feeGrowthGlobal1X128 : state.feeGrowthGlobalX128)
        );

        if (zeroForOne) {
          liquidityDelta = -liquidityDelta;
        }

        state.liquidity = LiquidityMath.addLiquidity(state.liquidity, liquidityDelta);

        if (state.liquidity == 0) {
          revert NotEnoughLiquidity();
        }

        state.tick = zeroForOne ? step.nextTick - 1 : step.nextTick;
      } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
        state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
      }
    }

    if (state.tick != slot0_.tick) {
      (uint16 observationIndex, uint16 observationCardinality) = observations.write(
        slot0.observationIndex,
        _blockTimestamp(),
        slot0.tick,
        slot0.observationCardinality,
        slot0.observationCardinalityNext
      );
      (slot0.sqrtPriceX96, slot0.tick, slot0.observationIndex, slot0.observationCardinality) = (
        state.sqrtPriceX96,
        state.tick,
        observationIndex,
        observationCardinality
      );
    } else {
      slot0.sqrtPriceX96 = state.sqrtPriceX96;
    }

    if (liquidity_ != state.liquidity) {
      liquidity = state.liquidity;
    }

    if (zeroForOne) {
      feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
    } else {
      feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
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

  function flash(uint256 amount0, uint256 amount1, bytes calldata data) public {
    uint256 fee0 = Math.mulDivRoundingUp(amount0, fee, 1e6);
    uint256 fee1 = Math.mulDivRoundingUp(amount1, fee, 1e6);

    uint256 balance0Before = IERC20(token0).balanceOf(address(this));
    uint256 balance1Before = IERC20(token1).balanceOf(address(this));

    if (amount0 > 0) {
      IERC20(token0).transfer(msg.sender, amount0);
    }
    if (amount1 > 0) {
      IERC20(token1).transfer(msg.sender, amount1);
    }

    IUniswapV3FlashCallback(msg.sender).uniswapV3FlashCallback(fee0, fee1, data);

    if (IERC20(token0).balanceOf(address(this)) < balance0Before + fee0) revert FlashLoanNotPaid();
    if (IERC20(token1).balanceOf(address(this)) < balance1Before + fee1) revert FlashLoanNotPaid();

    emit Flash(msg.sender, amount0, amount1);
  }

  function observe(uint32[] calldata secondsAgos) public view returns (int56[] memory tickCumulatives) {
    return observations.observe(_blockTimestamp(), secondsAgos, slot0.tick, slot0.observationIndex, slot0.observationCardinality);
  }

  function increaseObservationCardinalityNext(uint16 observationCardinalityNext) public {
    uint16 observationCardinalityNextOld = slot0.observationCardinalityNext;
    uint16 observationCardinalityNextNew = observations.grow(observationCardinalityNextOld, observationCardinalityNext);

    if (slot0.observationCardinalityNext != observationCardinalityNextNew) {
      slot0.observationCardinalityNext = observationCardinalityNextNew;
      emit IncreaseObservationCardinalityNext(observationCardinalityNextOld, observationCardinalityNextNew);
    }
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

  function _blockTimestamp() internal view virtual returns (uint32 timestamp) {
    timestamp = uint32(block.timestamp);
  }
}
