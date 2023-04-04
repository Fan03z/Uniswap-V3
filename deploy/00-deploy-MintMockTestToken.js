const { network } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  if (developmentChains.includes(network.name)) {
    log("Detected in local developmentChains and will mint test token...");

    log("----------------------");

    const WETH = await deploy("MockWETH", {
      from: deployer,
      args: [1],
      log: true,
      waitConfirmations: network.config.blockConfirmation || 1,
    });
    log(`WETH deploy in ${WETH.address}`);

    log("----------------------");

    const USDC = await deploy("MockUSDC", {
      from: deployer,
      // 5000个提供流动性,42个用于交易
      args: [5042],
      log: true,
      waitConfirmations: network.config.blockConfirmation || 1,
    });
    log(`USDC deploy in ${USDC.address}`);

    log("----------------------");
  }
};

module.exports.tags = ["all", "MintMockTestToken"];
