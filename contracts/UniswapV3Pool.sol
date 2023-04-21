// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.14;

// 下两者都可以从 @prb/math 包中获取到 mulDiv 函数
// import {mulDiv} from "@prb/math/src/SD59x18.sol";
import "@prb/math/src/SD59x18.sol" as PrbMath;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV3FlashCallback.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IUniswapV3PoolDeployer.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";

import "./lib/FixedPoint128.sol";
import "./lib/LiquidityMath.sol";
import "./lib/Math.sol";
import "./lib/Oracle.sol";
import "./lib/Position.sol";
import "./lib/SwapMath.sol";
import "./lib/Tick.sol";
import "./lib/TickBitmap.sol";
import "./lib/TickMath.sol";

/**
 * @title Uniswap V3 Pool
 * @notice 实现去中心化交易的核心逻辑,每一对币对都可以有一个对应的池子
 */
contract UniswapV3Pool is IUniswapV3Pool {
  using Oracle for Oracle.Observation[65535];
  using Position for Position.Info;
  using Position for mapping(bytes32 => Position.Info);
  using Tick for mapping(int24 => Tick.Info);
  using TickBitmap for mapping(int16 => uint256);

  error AlreadyInitialized();
  error FlashLoanNotPaid();
  error InsufficientInputAmount();
  error InvalidPriceLimit();
  // 提示tick范围不合理错误
  error InvalidTickRange();
  error NotEnoughLiquidity();
  error ZeroLiquidity();

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

  event Flash(address indexed recipient, uint256 amount0, uint256 amount1);

  event IncreaseObservationCardinalityNext(uint16 observationCardinalityNextOld, uint16 observationCardinalityNextNew);

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

  /**
   * @dev 池子合约参数变量
   * @notice 因为以下的变量都是在初始创建池子时就要设置好的了,所以都设置为 immutable 不可变变量
   */
  // 池子合约的工厂合约地址,所有池子都对应着同一个工厂合约
  address public immutable factory;
  // 池子中的交易币种0
  address public immutable token0;
  // 池子中的交易币种1
  address public immutable token1;
  // 每个 tick 之间的间隔,也就是 tick 的精度
  // 本项目简单实现的话，只提供 10 , 60 两档选择,实际上可能会多几项选择
  // 越稳定的币对,tickspacing就越小,因为价格变动的幅度越小
  uint24 public immutable tickSpacing;
  // 交易费率,对应着 tickspacing ,也是交易币对越稳定,交易费率越小
  // 同样本项目中只提供 0.05% 和 0.3% 两档选择
  // 具体对应关系在 factory工厂合约中
  uint24 public immutable fee;

  uint256 public feeGrowthGlobal0X128;
  uint256 public feeGrowthGlobal1X128;

  // 设置 Slot0结构体 ,跟踪记录当前的池子中的价格和tick等信息
  struct Slot0 {
    // 当前价格的平方根 (即sqrt(p))
    // 直接存储价格平方根,是因为很多地方计算都需要价格的平方根来进行计算,直接存储可以避免重复计算,还在一定程度上可以节省gas和保持精度
    uint160 sqrtPriceX96;
    // 当前的tick
    int24 tick;
    // Most recent observation index
    uint16 observationIndex;
    // Maximum number of observations
    uint16 observationCardinality;
    // Next maximum number of observations
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

  Slot0 public slot0;

  // 池子当前的流动性数量(只会涵盖当前价格范围上已激活的部分)
  uint128 public liquidity;

  // 第几个tick(int24) => 该tick上数据(Tick.Info)
  // 此映射用于记录每个 tick 的数据
  mapping(int24 => Tick.Info) public ticks;
  mapping(int16 => uint256) public tickBitmap;
  // 用户提供的流动性仓位/价格范围哈希[由owner, lowerTick, upperTick信息转化的哈希(具体看Position.sol上get()处)](bytes32) => 该范围上流动性和费率计算数据(Position.Info)
  // 此映射用于记录每个用户提供的流动性仓位上的流动性和费率奖励累计的数据
  mapping(bytes32 => Position.Info) public positions;
  Oracle.Observation[65535] public observations;

  constructor() {
    // 构造函数中,初始化池子合约参数
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

  struct ModifyPositionParams {
    address owner;
    int24 lowerTick;
    int24 upperTick;
    int128 liquidityDelta;
  }

  function _modifyPosition(
    ModifyPositionParams memory params
  ) internal returns (Position.Info storage position, int256 amount0, int256 amount1) {
    // gas optimizations
    Slot0 memory slot0_ = slot0;
    uint256 feeGrowthGlobal0X128_ = feeGrowthGlobal0X128;
    uint256 feeGrowthGlobal1X128_ = feeGrowthGlobal1X128;

    // 获取当前范围的流动性仓位数据
    position = positions.get(params.owner, params.lowerTick, params.upperTick);

    // 根据流动性变化,更新tick数据
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

    if (flippedLower) {
      tickBitmap.flipTick(params.lowerTick, int24(tickSpacing));
    }

    if (flippedUpper) {
      tickBitmap.flipTick(params.upperTick, int24(tickSpacing));
    }

    (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = ticks.getFeeGrowthInside(
      params.lowerTick,
      params.upperTick,
      slot0_.tick,
      feeGrowthGlobal0X128_,
      feeGrowthGlobal1X128_
    );

    // 更新流动性仓位数据
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
   * @dev 提供流动性
   * @param owner 提供token的所有者地址,用来记录是谁提供的流动性
   * @param lowerTick 期望提供流动性的价格区间下界(最小值)
   * @param upperTick 期望提供流动性的价格区间上界(最大值)
   * @param amount 期望提供的流动性数量
   * (注意: 此处是流动性数量,而不是token数,因为池子合约只实现核心逻辑,并不需要为用户提供方便,用户调用的时候也不是直接调用池子合约的,而是借用管理合约来调用实现的,会让用户在调用前实现token数量到流动性数量转换的)
   * @param data 附加数据
   * @return amount0 提供到token0的代币数量
   * @return amount1 提供到token1的代币数量
   * @notice 在 Uniswap V2 中,提供流动性被称作 铸造(mint),因为 Uniswap V2 的池子给予 LP-token 作为提供流动性的交换,
   * 虽然 V3 没有这种行为,但是仍然保留了同样的名字,V3 中是提供 NFT 作为提供流动性的证明的
   * 因为V2提供流动性是为全局提供的,即提供价格范围在(0～正无穷)上,所以是可以为提供流动性的用户发 LP-token 这种同质化证明的
   * 但V3提供流动性加入了范围概念,故发 流动性NFT 这种非同质化证明,在移除时也是通过回收NFT的方式来移除的
   */
  function mint(
    address owner,
    int24 lowerTick,
    int24 upperTick,
    uint128 amount,
    bytes calldata data
  ) external returns (uint256 amount0, uint256 amount1) {
    // 检查希望提供的tick范围是否合理
    if (lowerTick >= upperTick || lowerTick < TickMath.MIN_TICK || upperTick > TickMath.MAX_TICK) revert InvalidTickRange();

    // 检查希望提供的流动性数量是否为0
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

    IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);

    if (amount0 > 0 && balance0Before + amount0 > balance0()) revert InsufficientInputAmount();

    if (amount1 > 0 && balance1Before + amount1 > balance1()) revert InsufficientInputAmount();

    emit Mint(msg.sender, owner, lowerTick, upperTick, amount, amount0, amount1);
  }

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

  function collect(
    address recipient,
    int24 lowerTick,
    int24 upperTick,
    uint128 amount0Requested,
    uint128 amount1Requested
  ) public returns (uint128 amount0, uint128 amount1) {
    Position.Info storage position = positions.get(msg.sender, lowerTick, upperTick);

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

  function swap(
    address recipient,
    bool zeroForOne,
    uint256 amountSpecified,
    uint160 sqrtPriceLimitX96,
    bytes calldata data
  ) public returns (int256 amount0, int256 amount1) {
    // Caching for gas saving
    Slot0 memory slot0_ = slot0;
    uint128 liquidity_ = liquidity;

    if (
      zeroForOne
        ? sqrtPriceLimitX96 > slot0_.sqrtPriceX96 || sqrtPriceLimitX96 < TickMath.MIN_SQRT_RATIO
        : sqrtPriceLimitX96 < slot0_.sqrtPriceX96 || sqrtPriceLimitX96 > TickMath.MAX_SQRT_RATIO
    ) revert InvalidPriceLimit();

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

      (step.nextTick, ) = tickBitmap.nextInitializedTickWithinOneWord(state.tick, int24(tickSpacing), zeroForOne);

      step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.nextTick);

      (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
        state.sqrtPriceX96,
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
        state.feeGrowthGlobalX128 += PrbMath.mulDiv(step.feeAmount, FixedPoint128.Q128, state.liquidity);
      }

      if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
        int128 liquidityDelta = ticks.cross(
          step.nextTick,
          (zeroForOne ? state.feeGrowthGlobalX128 : feeGrowthGlobal0X128),
          (zeroForOne ? feeGrowthGlobal1X128 : state.feeGrowthGlobalX128)
        );

        if (zeroForOne) liquidityDelta = -liquidityDelta;

        state.liquidity = LiquidityMath.addLiquidity(state.liquidity, liquidityDelta);

        if (state.liquidity == 0) revert NotEnoughLiquidity();

        state.tick = zeroForOne ? step.nextTick - 1 : step.nextTick;
      } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
        state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
      }
    }

    if (state.tick != slot0_.tick) {
      (uint16 observationIndex, uint16 observationCardinality) = observations.write(
        slot0_.observationIndex,
        _blockTimestamp(),
        slot0_.tick,
        slot0_.observationCardinality,
        slot0_.observationCardinalityNext
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

    if (liquidity_ != state.liquidity) liquidity = state.liquidity;

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
      if (balance0Before + uint256(amount0) > balance0()) revert InsufficientInputAmount();
    } else {
      IERC20(token0).transfer(recipient, uint256(-amount0));

      uint256 balance1Before = balance1();
      IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
      if (balance1Before + uint256(amount1) > balance1()) revert InsufficientInputAmount();
    }

    emit Swap(msg.sender, recipient, amount0, amount1, slot0.sqrtPriceX96, state.liquidity, slot0.tick);
  }

  function flash(uint256 amount0, uint256 amount1, bytes calldata data) public {
    uint256 fee0 = Math.mulDivRoundingUp(amount0, fee, 1e6);
    uint256 fee1 = Math.mulDivRoundingUp(amount1, fee, 1e6);

    uint256 balance0Before = IERC20(token0).balanceOf(address(this));
    uint256 balance1Before = IERC20(token1).balanceOf(address(this));

    if (amount0 > 0) IERC20(token0).transfer(msg.sender, amount0);
    if (amount1 > 0) IERC20(token1).transfer(msg.sender, amount1);

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

    if (observationCardinalityNextNew != observationCardinalityNextOld) {
      slot0.observationCardinalityNext = observationCardinalityNextNew;
      emit IncreaseObservationCardinalityNext(observationCardinalityNextOld, observationCardinalityNextNew);
    }
  }

  ////////////////////////////////////////////////////////////////////////////
  //
  // INTERNAL 内部函数,只在合约内调用,故都设置为 internal
  //
  ////////////////////////////////////////////////////////////////////////////
  /**
   * @dev 获取当前地址下的token0的余额
   * @return balance token0的余额
   */
  function balance0() internal returns (uint256 balance) {
    // 注意token0要先接入IERC20接口,才能调用接口中定义好的ERC20提供的方法
    balance = IERC20(token0).balanceOf(address(this));
  }

  /**
   * @dev 获取当前地址下的token1的余额
   * @return balance token1的余额
   */
  function balance1() internal returns (uint256 balance) {
    // 理同上
    balance = IERC20(token1).balanceOf(address(this));
  }

  /**
   * @dev 获取当前区块的时间戳
   * @return timestamp 当前区块的时间戳
   * @notice 用于记录获得的价格预言机对应的区块时间戳
   */
  function _blockTimestamp() internal view returns (uint32 timestamp) {
    timestamp = uint32(block.timestamp);
  }
}
