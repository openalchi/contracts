import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
//import "@nomiclabs/hardhat-verify";

const config: HardhatUserConfig = {
  etherscan: {
    apiKey: {
      taiko: "taiko", // apiKey is not required, just set a placeholder
      Hekla: 'your API key'
    },
    customChains: [
      {
        network: "taiko",
        chainId: 167000,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/mainnet/evm/167000/etherscan",
          browserURL: "https://taikoscan.network"
        }
      },
      {
        network: "Hekla",
        chainId: 167009,
        urls: {
          apiURL: "https://taiko-hekla.blockpi.network/v1/rpc/public",
          browserURL: "https://taikoscan.network"
        }
      }
    ]
  },
  networks: {
    'Hekla': {
      url: `https://taiko-hekla.blockpi.network/v1/rpc/public`,
      chainId: 167009,
      accounts: [""]
    },
    taiko: {
      url: 'https://rpc.taiko.xyz',
      accounts: [""]
    },
  },
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: false,
        runs: 200
      }
    }
  },
  mocha: {
    timeout: 80000
  }
};

export default config;