require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-deploy");
require("solidity-coverage");
require("hardhat-gas-reporter");
require("hardhat-contract-sizer");
require("dotenv").config();
require("@nomicfoundation/hardhat-foundry");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

const MAINNET_RPC_URL = process.env.MAINNET_RPC_URL;
const GOERLI_RPC_URL = process.env.GOERLI_RPC_URL;
const POLYGON_MAINNET_RPC_URL = process.env.POLYGON_MAINNET_RPC_URL;

const PRIVATE_KEY = process.env.PRIVATE_KEY;
// optional
const MNEMONIC = process.env.MNEMONIC;

const ETHERSCAN_API_KEY =
  process.env.ETHERSCAN_API_KEY || "Your etherscan API key";
const POLYGONSCAN_API_KEY =
  process.env.POLYGONSCAN_API_KEY || "Your polygonscan API key";
const REPORT_GAS = process.env.REPORT_GAS === "true" || false;
const LOCAL_GANACHE_RPC_URL = process.env.LOCAL_GANACHE_RPC_URL;
const LOCAL_GANACHE_PRIVATE_KEY = process.env.LOCAL_GANACHE_PRIVATE_KEY;

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      // 暂时不fork主网络或其他网络了
      // forking: {
      //   url: MAINNET_RPC_URL,
      // },
      chainId: 31337,
      // 加上这句部署 01-deploy-UniswapV3Factory 时就不会报错:
      // Error: cannot estimate gas; transaction may fail or may require manual gas limit
      allowUnlimitedContractSize: true,
    },
    localhost: {
      chainId: 31337,
      allowUnlimitedContractSize: true,
    },
    ganache: {
      chainId: 5777,
      url: LOCAL_GANACHE_RPC_URL,
      accounts: PRIVATE_KEY !== undefined ? [LOCAL_GANACHE_PRIVATE_KEY] : [],
    },
    // goerli: {
    //   url: GOERLI_RPC_URL,
    //   accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
    //   //accounts: {
    //   //     mnemonic: MNEMONIC,
    //   // },
    //   saveDeployments: true,
    //   chainId: 5,
    //   blockConfirmations: 6,
    // },
    // mainnet: {
    //   url: MAINNET_RPC_URL,
    //   accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
    //   //   accounts: {
    //   //     mnemonic: MNEMONIC,
    //   //   },
    //   saveDeployments: true,
    //   chainId: 1,
    //   blockConfirmations: 6,
    // },
    // polygon: {
    //   url: POLYGON_MAINNET_RPC_URL,
    //   accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
    //   saveDeployments: true,
    //   chainId: 137,
    //   blockConfirmations: 6,
    // },
  },
  etherscan: {
    // npx hardhat verify --network <NETWORK> <CONTRACT_ADDRESS> <CONSTRUCTOR_PARAMETERS>
    apiKey: {
      goerli: ETHERSCAN_API_KEY,
      polygon: POLYGONSCAN_API_KEY,
    },
  },
  gasReporter: {
    enabled: REPORT_GAS,
    currency: "USD",
    outputFile: "gas-report.txt",
    noColors: true,
    // coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  },
  contractSizer: {
    runOnCompile: false,
    only: ["OurToken"],
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
    },
    user1: {
      default: 1,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.14",
      },
      {
        version: "0.4.24",
      },
    ],
  },
  mocha: {
    timeout: 200000, // 200 seconds max for running tests
  },
};
