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
const VERIFICATION_BLOCK_CONFIRMATIONS = 6;

const frontEndContractsFile = "./ui/constants/address.json";
const frontEndAbiLocation = "../ui/constants/abi/";

module.exports = {
  networkConfig,
  developmentChains,
  VERIFICATION_BLOCK_CONFIRMATIONS,
  frontEndContractsFile,
  frontEndAbiLocation,
};
