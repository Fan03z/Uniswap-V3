const config = {
  // contract address
  wethAddress: "0x...",
  factoryAddress: "0x...",
  managerAddress: "0x...",
  quoterAddress: "0x...",
  // contract abi
  ABIs: {
    ERC20: require("./abi/ERC20.json"),
    Factory: require("./abi/Factory.json"),
    Manager: require("./abi/Manager.json"),
    Pool: require("./abi/Pool.json"),
    Quoter: require("./abi/Quoter.json"),
  },
};

export default config;
