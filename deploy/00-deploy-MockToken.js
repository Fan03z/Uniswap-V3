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

    log("Minting and approving test token...");

    const wbtc = new ethers.Contract(WBTC.address, WBTC.abi, owner);
    const WBTCMintTx = await wbtc.mint(owner.address, 30);
    await WBTCMintTx.wait(1);
    log(`30 WBTC mint to ${owner.address}`);

    const WBTCApproveTx = await wbtc.approve(owner.address, 30);
    await WBTCApproveTx.wait(1);

    const weth = new ethers.Contract(WETH.address, WETH.abi, owner);
    const WETHMintTx = await weth.mint(owner.address, 100);
    await WETHMintTx.wait(1);
    log(`100 WETH mint to ${owner.address}`);

    const WETHApproveTx = await weth.approve(owner.address, 100);
    await WETHApproveTx.wait(1);

    const uni = new ethers.Contract(UNI.address, UNI.abi, owner);
    const UNIMintTx = await uni.mint(owner.address, 400000);
    await UNIMintTx.wait(1);
    log(`400000 UNI mint to ${owner.address}`);

    const UNIApproveTx = await uni.approve(owner.address, 400000);
    await UNIApproveTx.wait(1);

    const usdc = new ethers.Contract(USDC.address, USDC.abi, owner);
    const USDCMintTx = await usdc.mint(owner.address, 500000);
    await USDCMintTx.wait(1);
    log(`500000 USDC mint to ${owner.address}`);

    const USDCApproveTx = await usdc.approve(owner.address, 500000);
    await USDCApproveTx.wait(1);

    const usdt = new ethers.Contract(USDT.address, USDT.abi, owner);
    const USDTMintTx = await usdt.mint(owner.address, 500000);
    await USDTMintTx.wait(1);
    log(`500000 USDT mint to ${owner.address}`);

    const USDTApproveTx = await usdt.approve(owner.address, 500000);
    await USDTApproveTx.wait(1);

    log("----------------------");
  }
};

module.exports.tags = ["all", "mockToken"];
