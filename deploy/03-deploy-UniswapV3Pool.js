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
  }
};

module.exports.tags = ["all", "uniswapV3Pool"];
