// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "abdk-math/ABDKMath64x64.sol";

import "../../contracts/interfaces/IUniswapV3Pool.sol";
import "../../contracts/interfaces/IUniswapV3Manager.sol";
import "../../contracts/lib/FixedPoint96.sol";
import "../../contracts/UniswapV3Factory.sol";
import "../../contracts/UniswapV3Pool.sol";

import "./ERC20Mintable.sol";
import "./Assertions.sol";

abstract contract TestUtils is Test, Assertions {
  mapping(uint24 => uint24) internal tickSpacings;

  constructor() {
    // 0.05% => 10
    tickSpacings[500] = 10;
    // 0.3% => 60
    tickSpacings[3000] = 60;
  }

  function divRound(int128 x, int128 y) internal pure returns (int128 result) {
    int128 quot = ABDKMath64x64.div(x, y);
    result = quot >> 64;

    // 检查余数是否大于0.5
    if (quot % 2 ** 64 >= 0x8000000000000000) result += 1;
  }

  // 参考: https://github.com/Uniswap/v3-sdk/blob/b6cd73a71f8f8ec6c40c130564d3aff12c38e693/src/utils/nearestUsableTick.ts
  function nearestUsableTick(int24 tick_, uint24 tickSpacing) internal pure returns (int24 result) {
    result = int24(divRound(int128(tick_), int128(int24(tickSpacing)))) * int24(tickSpacing);

    if (result < TickMath.MIN_TICK) {
      result += int24(tickSpacing);
    } else if (result > TickMath.MAX_TICK) {
      result -= int24(tickSpacing);
    }
  }

  function sqrtP(uint256 price) internal pure returns (uint160) {
    return uint160(int160(ABDKMath64x64.sqrt(int128(int256(price << 64))) << (FixedPoint96.RESOLUTION - 64)));
  }

  // 在 60 tick间隔上,通过 price 计算出 sqrtP
  function sqrtP60(uint256 price) internal pure returns (uint160) {
    return TickMath.getSqrtRatioAtTick(tick60(price));
  }

  // 在 60 tick间隔上,通过 所在tick 计算出 sqrtP
  function sqrtP60FromTick(int24 tick_) internal pure returns (uint160) {
    return TickMath.getSqrtRatioAtTick(nearestUsableTick(tick_, 60));
  }

  // 计算出具体的tick,但不一定是最后的,还要检查是否到了周围可用的
  function tick(uint256 price) internal pure returns (int24 tick_) {
    tick_ = TickMath.getTickAtSqrtRatio(sqrtP(price));
  }

  // 在 60 tick间隔上,通过 price 计算出 tick
  function tick60(uint256 price) internal pure returns (int24 tick_) {
    tick_ = tick(price);
    tick_ = nearestUsableTick(tick_, 60);
  }

  // 在 60 tick间隔上,通过 sqrtP 计算出 tick
  function sqrtPToNearestTick(uint160 sqrtP_, uint24 tickSpacing) internal pure returns (int24 tick_) {
    tick_ = TickMath.getTickAtSqrtRatio(sqrtP_);
    tick_ = nearestUsableTick(tick_, tickSpacing);
  }

  function encodeError(string memory error) internal pure returns (bytes memory encoded) {
    encoded = abi.encodeWithSignature(error);
  }

  function encodeSlippageCheckFailed(uint256 amount0, uint256 amount1) internal pure returns (bytes memory encoded) {
    encoded = abi.encodeWithSignature("SlippageCheckFailed(uint256,uint256)", amount0, amount1);
  }

  function encodeExtra(address token0_, address token1_, address payer) internal pure returns (bytes memory) {
    return abi.encode(IUniswapV3Pool.CallbackData({token0: token0_, token1: token1_, payer: payer}));
  }

  function mintParams(
    address tokenA,
    address tokenB,
    uint256 lowerPrice,
    uint256 upperPrice,
    uint256 amount0,
    uint256 amount1
  ) internal pure returns (IUniswapV3Manager.MintParams memory params) {
    params = IUniswapV3Manager.MintParams({
      tokenA: tokenA,
      tokenB: tokenB,
      fee: 3000,
      lowerTick: tick60(lowerPrice),
      upperTick: tick60(upperPrice),
      amount0Desired: amount0,
      amount1Desired: amount1,
      amount0Min: 0,
      amount1Min: 0
    });
  }

  function mintParams(
    address tokenA,
    address tokenB,
    uint160 lowerSqrtP,
    uint160 upperSqrtP,
    uint256 amount0,
    uint256 amount1,
    uint24 fee
  ) internal view returns (IUniswapV3Manager.MintParams memory params) {
    params = IUniswapV3Manager.MintParams({
      tokenA: tokenA,
      tokenB: tokenB,
      fee: fee,
      lowerTick: sqrtPToNearestTick(lowerSqrtP, tickSpacings[fee]),
      upperTick: sqrtPToNearestTick(upperSqrtP, tickSpacings[fee]),
      amount0Desired: amount0,
      amount1Desired: amount1,
      amount0Min: 0,
      amount1Min: 0
    });
  }

  function deployPool(
    UniswapV3Factory factory,
    address token0,
    address token1,
    uint24 fee,
    uint256 currentPrice
  ) internal returns (UniswapV3Pool pool) {
    pool = UniswapV3Pool(factory.createPool(token0, token1, fee));
    pool.initialize(sqrtP(currentPrice));
  }
}
