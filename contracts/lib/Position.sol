// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

library Position {
  struct Info {
    uint128 liquidity;
  }

  /**
   * @dev 更新指定位置的流动性(与Tick.update()类似)
   * @param self Info
   * @param liquidityDelta 流动性变化量
   */
  function update(Info storage self, uint128 liquidityDelta) internal {
    uint128 liquidityBefore = self.liquidity;
    uint128 liquidityAfter = liquidityBefore + liquidityDelta;

    self.liquidity = liquidityAfter;
  }

  /**
   * @dev 获得指定位置的流动性
   * @param self mapping(bytes32 => Position.Info)
   * @param owner 提供流动性的账户地址
   * @param upperTick tick上界
   * @param lowerTick tick下界
   * @return position Position.Info类型数据,包含了查询账户提供的流动性
   */
  function get(
    mapping(bytes32 => Info) storage self,
    address owner,
    int24 upperTick,
    int24 lowerTick
  ) internal view returns (Position.Info storage position) {
    position = self[keccak256(abi.encodePacked(owner, lowerTick, upperTick))];
  }
}
