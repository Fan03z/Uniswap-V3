// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./LiquidityMath.sol";

library Tick {
  struct Info {
    bool initialized;
    // 当前处于激活状态的总流动性
    uint128 liquidityGross;
    // 跨越tick交叉时的流动性变化
    int128 liquidityNet;
  }

  /**
   * @dev 更新流动性
   * @param self mapping(int24 => Tick.Info)
   * @param tick tick
   * @param liquidityDelta 流动性变化量
   * @param upper 流动性增减方向
   */
  function update(
    mapping(int24 => Tick.Info) storage self,
    int24 tick,
    int128 liquidityDelta,
    bool upper
  ) internal returns (bool flipped) {
    Tick.Info storage tickInfo = self[tick];

    uint128 liquidityBefore = tickInfo.liquidityGross;
    uint128 liquidityAfter = LiquidityMath.addLiquidity(liquidityBefore, liquidityDelta);

    flipped = (liquidityAfter == 0) != (liquidityBefore == 0);

    if (liquidityBefore == 0) {
      tickInfo.initialized = true;
    }

    tickInfo.liquidityGross = liquidityAfter;
    tickInfo.liquidityNet = upper
      ? int128(int256(tickInfo.liquidityNet) + liquidityDelta)
      : int128(int256(tickInfo.liquidityNet) - liquidityDelta);
  }

  function cross(mapping(int24 => Tick.Info) storage self, int24 tick) internal view returns (int128 liquidityDelta) {
    Tick.Info storage info = self[tick];
    liquidityDelta = info.liquidityNet;
  }
}
