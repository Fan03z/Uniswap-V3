const { network, ethers } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  if (developmentChains.includes(network.name)) {
    // 要将 ethers 的版本控在 @5.4.0 ,新的测试版会报错:
    // TypeError: Cannot read properties of undefined (reading 'JsonRpcProvider')
    const [owner, addr1, addr2, addr3, addr4, addr5] =
      await ethers.getSigners();

    log("Detected in local developmentChains and will mint test token...");

    log("----------------------");

    const WETHArgs = ["Wrapped Ether", "WETH"];

    const WETH = await deploy("WETHContract", {
      from: deployer,
      contract: "MockToken",
      args: WETHArgs,
      log: false,
      waitConfirmations: network.config.blockConfirmation || 1,
    });
    log(`WETH deploy in ${WETH.address}`);

    log("----------------------");

    const USDCArgs = ["USD Coin", "USDC"];

    const USDC = await deploy("USDCContract", {
      from: deployer,
      args: USDCArgs,
      contract: "MockToken",
      log: false,
      waitConfirmations: network.config.blockConfirmation || 1,
    });
    log(`USDC deploy in ${USDC.address}`);

    log("----------------------");

    const UNIArgs = ["Uniswap Coin", "UNI"];

    const UNI = await deploy("UNIContract", {
      from: deployer,
      args: UNIArgs,
      contract: "MockToken",
      log: false,
      waitConfirmations: network.config.blockConfirmation || 1,
    });
    log(`UNI deploy in ${UNI.address}`);

    log("----------------------");

    const WBTCArgs = ["Wrapped Bitcoin", "WBTC"];

    const WBTC = await deploy("WBTCContract", {
      from: deployer,
      args: WBTCArgs,
      contract: "MockToken",
      log: false,
      waitConfirmations: network.config.blockConfirmation || 1,
    });
    log(`WBTC deploy in ${WBTC.address}`);

    log("----------------------");

    const USDTArgs = ["USD Token", "USDT"];

    const USDT = await deploy("USDTContract", {
      from: deployer,
      args: USDTArgs,
      contract: "MockToken",
      log: false,
      waitConfirmations: network.config.blockConfirmation || 1,
    });
    log(`USDT deploy in ${USDT.address}`);

    log("----------------------");

    log("Minting test token...");

    const wbtc = new ethers.Contract(WBTC.address, WBTC.abi, owner);
    const WBTCMintTx = await wbtc.mint(addr1.address, 30);
    await WBTCMintTx.wait(1);
    log(`30 WBTC mint to ${addr1.address}`);

    const weth = new ethers.Contract(WETH.address, WETH.abi, owner);
    const WETHMintTx = await weth.mint(addr2.address, 100);
    await WETHMintTx.wait(1);
    log(`100 WETH mint to ${addr2.address}`);

    const uni = new ethers.Contract(UNI.address, UNI.abi, owner);
    const UNIMintTx = await uni.mint(addr3.address, 400000);
    await UNIMintTx.wait(1);
    log(`400000 UNI mint to ${addr3.address}`);

    const usdc = new ethers.Contract(USDC.address, USDC.abi, owner);
    const USDCMintTx = await usdc.mint(addr4.address, 500000);
    await USDCMintTx.wait(1);
    log(`500000 USDC mint to ${addr4.address}`);

    const usdt = new ethers.Contract(USDT.address, USDT.abi, owner);
    const USDTMintTx = await usdt.mint(addr5.address, 500000);
    await USDTMintTx.wait(1);
    log(`500000 USDT mint to ${addr5.address}`);

    log("----------------------");
  }
};

module.exports.tags = ["all", "mockToken"];
