const { ethers } = require("hardhat");

const deployPool = async (token0, token1, fee, currentPrice) => {
  const factory = await ethers.getContract("UniswapV3Factory");
  const poolContract = await ethers.getContractFactory("UniswapV3Pool");

  const poolAddress = await factory.creactPool(token0, token1, fee);
  const pool = await poolContract.attach(poolAddress);

  pool.initialize(currentPrice);
};

export default deployPool;
