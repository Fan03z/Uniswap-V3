const { network, ethers } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");
const { deployPool } = require("../utils/deployPool");
const { verify } = require("../utils/verify");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const [owner] = await ethers.getSigners();

  if (developmentChains.includes(network.name)) {
    const factory = await ethers.getContract("UniswapV3Factory");
    const manager = await ethers.getContract("UniswapV3Manager");
    const WETH = await ethers.getContract("WETHContract");
    const USDC = await ethers.getContract("USDCContract");
    const UNI = await ethers.getContract("UNIContract");
    const WBTC = await ethers.getContract("WBTCContract");
    const USDT = await ethers.getContract("USDTContract");

    const wethUsdc = await deployPool(
      factory,
      WETH.address,
      USDC.address,
      3000,
      5000
    );
    log(`WETH/USDC pool address: ${wethUsdc.address}`);

    const wethUni = await deployPool(
      factory,
      WETH.address,
      UNI.address,
      3000,
      10
    );
    log(`WETH/UNI pool address: ${wethUni.address}`);

    const wbtcUsdt = await deployPool(
      factory,
      WBTC.address,
      USDT.address,
      3000,
      20000
    );
    log(`WBTC/USDT pool address: ${wbtcUsdt.address}`);

    const usdtUsdc = await deployPool(
      factory,
      USDT.address,
      USDC.address,
      500,
      1
    );
    log(`USDT/USDC pool address: ${usdtUsdc.address}`);

    log("----------------------");

    log("Adding liquidity to pool...");

    // FIXME:
    // wethUsdc
    const Addliquidity = await manager.mint({
      tokenA: WETH.address,
      tokenB: USDC.address,
      fee: 3000,
      lowerTick: 4545,
      upperTick: 5500,
      amount0Desired: ethers.utils.parseEther("1"),
      amount1Desired: ethers.utils.parseEther("5000"),
      amount0Min: ethers.utils.parseEther("0.5"),
      amount1Min: ethers.utils.parseEther("2500"),
    });
    await Addliquidity.wait(1);
    log(Addliquidity);
  }
};

module.exports.tags = ["all", "uniswapV3Pool"];
