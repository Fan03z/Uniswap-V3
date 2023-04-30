const { network } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const UniswapV3FactoryArgs = [];

  const UniswapV3Factory = await deploy("UniswapV3Factory", {
    from: deployer,
    args: UniswapV3FactoryArgs,
    log: false,
    waitConfirmations: network.config.blockConfirmations || 1,
  });
  log(`UniswapV3Factory address: ${UniswapV3Factory.address}`);

  log("----------------------");

  if (
    !developmentChains.includes(network.name) &&
    process.env.ETHERSCAN_API_KEY
  ) {
    log("Wait to verify UniswapV3Factory...");
    await verify(UniswapV3Factory.address, UniswapV3FactoryArgs);

    log("----------------------");
  }
};

module.tags = ["all", "uniswapV3Factory"];
