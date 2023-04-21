// SPDX-License-Identifier:  GPL-2.0-or-later
pragma solidity ^0.8.14;

import "./FixedPoint96.sol";
import {mulDiv} from "@prb/math/src/SD59x18.sol";

library LiquidityMath {
  // 根据tokenx计算L公式:
  /// $L = \frac{\Delta x \sqrt{P_u} \sqrt{P_l}}{\Delta \sqrt{P}}$
  function getLiquidityForAmount0(
    uint160 sqrtPriceAX96,
    uint160 sqrtPriceBX96,
    uint256 amount0
  ) internal pure returns (uint128 liquidity) {
    if (sqrtPriceAX96 > sqrtPriceBX96) {
      (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
    }

    uint256 intermediate = mulDiv(sqrtPriceAX96, sqrtPriceBX96, FixedPoint96.Q96);
    liquidity = uint128(mulDiv(amount0, intermediate, sqrtPriceBX96 - sqrtPriceAX96));
  }

  // 根据tokeny计算L公式:
  /// $L = \frac{\Delta y}{\Delta \sqrt{P}}$
  function getLiquidityForAmount1(
    uint160 sqrtPriceAX96,
    uint160 sqrtPriceBX96,
    uint256 amount1
  ) internal pure returns (uint128 liquidity) {
    if (sqrtPriceAX96 > sqrtPriceBX96) {
      (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
    }

    liquidity = uint128(mulDiv(amount1, FixedPoint96.Q96, sqrtPriceBX96 - sqrtPriceAX96));
  }

  function getLiquidityForAmounts(
    uint160 sqrtPriceX96,
    uint160 sqrtPriceAX96,
    uint160 sqrtPriceBX96,
    uint256 amount0,
    uint256 amount1
  ) internal pure returns (uint128 liquidity) {
    if (sqrtPriceAX96 > sqrtPriceBX96) {
      (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
    }

    if (sqrtPriceX96 <= sqrtPriceAX96) {
      liquidity = getLiquidityForAmount0(sqrtPriceAX96, sqrtPriceBX96, amount0);
    } else if (sqrtPriceX96 <= sqrtPriceBX96) {
      uint128 liquidity0 = getLiquidityForAmount0(sqrtPriceX96, sqrtPriceBX96, amount0);
      uint128 liquidity1 = getLiquidityForAmount1(sqrtPriceAX96, sqrtPriceX96, amount1);

      liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
    } else {
      liquidity = getLiquidityForAmount1(sqrtPriceAX96, sqrtPriceBX96, amount1);
    }
  }

  /**
   * @dev 计算流动性
   * @param x 流动性计算前值
   * @param y 流动性变化量
   * @return z 流动性计算后值
   */
  function addLiquidity(uint128 x, int128 y) internal pure returns (uint128 z) {
    if (y < 0) {
      z = x - uint128(-y);
    } else {
      z = x + uint128(y);
    }
  }
}
