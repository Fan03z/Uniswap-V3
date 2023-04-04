const networkConfig = {
  5: {
    name: "goerli",
  },
  31337: {
    name: "localhost",
  },
  5777: {
    name: "ganache",
  },
};

const developmentChains = ["hardhat", "localhost", "ganache"];

module.exports = {
  networkConfig,
  developmentChains,
};
