// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./FixedPoint128.sol";
import "./LiquidityMath.sol";
import {mulDiv} from "@prb/math/src/SD59x18.sol";

library Position {
  struct Info {
    // 价格范围对应的流动性数量
    uint128 liquidity;
    uint256 feeGrowthInside0LastX128;
    uint256 feeGrowthInside1LastX128;
    uint128 tokensOwed0;
    uint128 tokensOwed1;
  }

  /**
   * @dev 更新指定范围的流动性(与Tick.update()类似)
   * @param self 某一价格范围
   * @param liquidityDelta 流动性变化量
   */
  function update(Info storage self, int128 liquidityDelta, uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) internal {
    uint128 tokensOwed0 = uint128(
      mulDiv(feeGrowthInside0X128 - self.feeGrowthInside0LastX128, self.liquidity, FixedPoint128.Q128)
    );
    uint128 tokensOwed1 = uint128(
      mulDiv(feeGrowthInside1X128 - self.feeGrowthInside1LastX128, self.liquidity, FixedPoint128.Q128)
    );

    // 为self价格范围添加流动性
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
   * @param self mapping(bytes32 => Position.Info) 记录了每一位用户提供的流动性范围信息的映射,在池子合约中定义了的
   * @param owner 提供流动性的账户地址
   * @param upperTick 指定价格范围对应的tick上界
   * @param lowerTick 指定价格范围对应的tick下界
   * @return position Position.Info结构体类型数据,包含了查询账户提供的流动性等信息
   */
  function get(
    mapping(bytes32 => Info) storage self,
    address owner,
    int24 lowerTick,
    int24 upperTick
  ) internal view returns (Position.Info storage position) {
    // 此处用keccak256()函数计算出的bytes32类型的值作为key,来查询mapping中的value
    // 用owner, lowerTick, upperTick信息打包转换的哈希作为索引key的原因:
    // 1.这三个值可以确定一个提供流动性的仓位
    // 2.这样更节省gas,这个数据是要存储到链上的,owner, lowerTick, upperTick分开存储是要96个字节,而转换为哈希存储只需要32个字节
    // 注意: 96 - 48 = 48,这样算下来,一个地址居然有48个字节,但地址信息才20个字节
    // 其实是因为存储的不仅仅是公钥地址信息,还包括了其他信息,例如版本号、校验等
    position = self[keccak256(abi.encodePacked(owner, lowerTick, upperTick))];
  }
}
