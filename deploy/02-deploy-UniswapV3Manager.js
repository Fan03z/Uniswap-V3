const { network, ethers } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  // FIXME: ???:是否要先部署Manager合约里面的lib合约库,此处好像不需要也可以部署Manager合约
  const LiquidityMath = await deploy("LiquidityMath", {
    from: deployer,
    log: false,
    waitConfirmations: network.config.blockConfirmations || 1,
  });
  const TickMath = await deploy("TickMath", {
    from: deployer,
    log: false,
    waitConfirmations: network.config.blockConfirmations || 1,
  });
  const Path = await deploy("Path", {
    from: deployer,
    log: false,
    waitConfirmations: network.config.blockConfirmations || 1,
  });
  const PoolAddress = await deploy("PoolAddress", {
    from: deployer,
    log: false,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

  const UniswapV3Factory = await ethers.getContract("UniswapV3Factory");

  // Manager要在创建池子合约前就得部署
  const UniswapV3Manager = await deploy("UniswapV3Manager", {
    from: deployer,
    args: [UniswapV3Factory.address],
    log: false,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

  log(`UniswapV3Manager address: ${UniswapV3Manager.address}`);

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

module.exports.tags = ["all", "uniswapV3Manager"];
