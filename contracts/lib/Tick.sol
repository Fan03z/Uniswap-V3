// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

library Tick {
  struct Info {
    bool initialized;
    uint128 liquidity;
  }

  /**
   * @dev 更新从self中获得的指定tick对应的Tick.Info对象中的liquidity
   * @param self mapping(int24 => Tick.Info)
   * @param tick tick
   * @param liquidityDelta 流动性变化量
   */
  function update(mapping(int24 => Tick.Info) storage self, int24 tick, uint128 liquidityDelta) internal returns (bool flipped) {
    Tick.Info storage tickInfo = self[tick];
    uint128 liquidityBefore = tickInfo.liquidity;
    uint128 liquidityAfter = liquidityBefore + liquidityDelta;

    flipped = (liquidityAfter == 0) != (liquidityBefore == 0);

    if (liquidityBefore == 0) {
      tickInfo.initialized = true;
    }

    tickInfo.liquidity = liquidityAfter;
  }
}
