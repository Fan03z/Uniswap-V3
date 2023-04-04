const { network, ethers } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  let UniswapV3PoolArgs = [];

  if (developmentChains.includes(network.name)) {
    const WETH = await ethers.getContract("MockWETH", deployer);
    const USDC = await ethers.getContract("MockUSDC", deployer);

    // 硬编码tick和sqrt(p),用于本地测试
    const currentTick = 85176;
    const currentSqrtP = ethers.BigNumber.from(
      "5602277097478614198912276234240"
    );

    UniswapV3PoolArgs = [WETH.address, USDC.address, currentSqrtP, currentTick];

    log("----------------------");
  }

  // 待处理
  if (!developmentChains.includes(network.name)) {
    UniswapV3PoolArgs = [];
  }

  const UniswapV3Pool = await deploy("UniswapV3Pool", {
    from: deployer,
    args: UniswapV3PoolArgs,
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

  if (
    !developmentChains.includes(network.name) &&
    process.env.ETHERSCAN_API_KEY
  ) {
    log("Wait to verify UniswapV3Pool...");
    await verify(UniswapV3Pool.address, UniswapV3PoolArgs);

    log("----------------------");
  }
};

module.exports.tags = ["all", "UniswapV3Pool"];
