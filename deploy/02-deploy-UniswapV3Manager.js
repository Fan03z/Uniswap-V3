const { network, ethers } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const UniswapV3Manager = await deploy("UniswapV3Manager", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

  log("----------------------");

  if (
    !developmentChains.includes(network.name) &&
    process.env.ETHERSCAN_API_KEY
  ) {
    log("Wait to verify UniswapV3Manager...");
    await verify(UniswapV3Manager.address, []);

    log("----------------------");
  }
};

module.exports.tags = ["all", "UniswapV3Manager"];
