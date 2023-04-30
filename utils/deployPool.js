const { ethers } = require("hardhat");
const poolABI = require("../ui/constants/abi/Pool.json");

const deployPool = async (factory, token0, token1, fee, currentPrice) => {
  const [owner] = await ethers.getSigners();

  const createPoolTx = await factory.createPool(token0, token1, fee);
  const txReceipt = await createPoolTx.wait(1);
  const poolAddress = txReceipt.events[0].args.pool;

  const pool = new ethers.Contract(poolAddress, poolABI, owner);

  pool.initialize(Math.sqrt(currentPrice));

  return pool;
};

module.exports = { deployPool };
