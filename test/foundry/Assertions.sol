// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";

import "../../contracts/UniswapV3Pool.sol";
import "../../contracts/UniswapV3NFTManager.sol";

import "./ERC20Mintable.sol";

abstract contract Assertions is Test {
  struct ExpectedPoolState {
    UniswapV3Pool pool;
    uint128 liquidity;
    uint160 sqrtPriceX96;
    int24 tick;
    uint256[2] fees;
  }

  function assertPoolState(ExpectedPoolState memory expected) internal {
    (uint160 sqrtPriceX96, int24 currentTick, , , ) = expected.pool.slot0();
    assertEq(sqrtPriceX96, expected.sqrtPriceX96, "invalid current sqrtP");
    assertEq(currentTick, expected.tick, "invalid current tick");
    assertEq(expected.pool.liquidity(), expected.liquidity, "invalid current liquidity");
    assertEq(expected.pool.feeGrowthGlobal0X128(), expected.fees[0], "incorrect feeGrowthGlobal0X128");
    assertEq(expected.pool.feeGrowthGlobal1X128(), expected.fees[1], "incorrect feeGrowthGlobal1X128");
  }

  struct ExpectedBalances {
    UniswapV3Pool pool;
    ERC20Mintable[2] tokens;
    uint256 userBalance0;
    uint256 userBalance1;
    uint256 poolBalance0;
    uint256 poolBalance1;
  }

  function assertBalances(ExpectedBalances memory expected) internal {}
}
