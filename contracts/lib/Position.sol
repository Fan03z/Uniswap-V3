// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./FixedPoint128.sol";
import "./LiquidityMath.sol";
import {mulDiv} from "@prb/math/src/SD59x18.sol";

library Position {
  struct Info {
    uint128 liquidity;
    uint256 feeGrowthInside0LastX128;
    uint256 feeGrowthInside1LastX128;
    uint128 tokensOwed0;
    uint128 tokensOwed1;
  }

  /**
   * @dev 更新指定位置的流动性(与Tick.update()类似)
   * @param self Info
   * @param liquidityDelta 流动性变化量
   */
  function update(Info storage self, int128 liquidityDelta, uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) internal {
    uint128 tokensOwed0 = uint128(
      mulDiv(feeGrowthInside0X128 - self.feeGrowthInside0LastX128, self.liquidity, FixedPoint128.Q128)
    );
    uint128 tokensOwed1 = uint128(
      mulDiv(feeGrowthInside1X128 - self.feeGrowthInside1LastX128, self.liquidity, FixedPoint128.Q128)
    );

    self.liquidity = LiquidityMath.addLiquidity(self.liquidity, liquidityDelta);
    self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
    self.feeGrowthInside1LastX128 = feeGrowthInside1X128;

    if (tokensOwed0 > 0 || tokensOwed1 > 0) {
      self.tokensOwed0 += tokensOwed0;
      self.tokensOwed1 += tokensOwed1;
    }
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
    int24 lowerTick,
    int24 upperTick
  ) internal view returns (Position.Info storage position) {
    position = self[keccak256(abi.encodePacked(owner, lowerTick, upperTick))];
  }
}
