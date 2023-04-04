// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../contracts/lib/Tick.sol";
import "../contracts/lib/Position.sol";
import "../contracts/interfaces/IERC20.sol";
import "../contracts/interfaces/IUniswapV3MintCallback.sol";
import "../contracts/interfaces/IUniswapV3SwapCallback.sol";

contract UniswapV3Pool {
  using Tick for mapping(int24 => Tick.Info);
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
  mapping(bytes32 => Position.Info) public positions;

  // 打包变量,方便同时读取
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
    ticks.update(upperTick, amount);
    ticks.update(lowerTick, amount);

    // 获得指定账户提供的流动性值
    Position.Info storage position = positions.get(owner, lowerTick, upperTick);

    // 更新账户流动性
    position.update(amount);

    // 硬编码,临时测试使用,后面要换的
    amount0 = 0.998976618347425280 ether;
    amount1 = 5000 ether;

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
   * @return amount0
   * @return amount1
   */
  function swap(address recipient, bytes calldata data) public returns (int256 amount0, int256 amount1) {
    // 依旧先硬编码,后面再换
    int24 nextTick = 85184;
    uint160 nextPrice = 5604469350942327889444743441197;
    amount0 = -0.008396714242162444 ether;
    amount1 = 42 ether;

    (slot0.tick, slot0.sqrtPriceX96) = (nextTick, nextPrice);

    IERC20(token0).transfer(recipient, uint256(-amount0));

    uint256 balance1Before = balance1();
    IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
    if (balance1Before + uint256(amount1) < balance1()) {
      revert InsufficientInputAmount();
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
