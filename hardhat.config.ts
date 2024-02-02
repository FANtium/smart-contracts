import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-abi-exporter";
import "hardhat-contract-sizer";
import "hardhat-interface-generator";
import "@openzeppelin/hardhat-defender";

import { config as dotenvConfig } from 'dotenv'
import { resolve } from 'path'
dotenvConfig({ path: resolve(__dirname, './.env') })

const POLYGON_MUMBAI_RPC_PROVIDER = process.env.POLYGON_MUMBAI_RPC_PROVIDER || ''
const PRIVATE_KEY = process.env.PRIVATE_KEY || ''
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY || ''
const GOERLISCAN_API_KEY = process.env.GOERLISCAN_API_KEY || ''
const SEPOLIASCAN_API_KEY = process.env.GOERLISCAN_API_KEY || ''
const DEFENDER_TEAM_API_KEY = process.env.DEFENDER_TEAM_API_KEY || ''
const DEFENDER_TEAM_API_SECRET = process.env.DEFENDER_TEAM_API_SECRET_KEY || ''
const POLYGON_RPC_PROVIDER = process.env.POLYGON_RPC_PROVIDER || ''

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.13',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          }

        }
      },
    ],
  }, defender: {
    apiKey: DEFENDER_TEAM_API_KEY,
    apiSecret: DEFENDER_TEAM_API_SECRET,
  },
  networks: {
    hardhat: {},
    polygon: {
      accounts: ["0x" + PRIVATE_KEY],
      url: POLYGON_RPC_PROVIDER
    },
    mumbai: {
      accounts: ["0x" + PRIVATE_KEY],
      url: POLYGON_MUMBAI_RPC_PROVIDER,
      gasPrice: 3000000000000,
      // gas: 8000000,
    },
    goerli: {
      url: "https://goerli.infura.io/v3/3c43c6fdb9c94a0ebd60ba9479abde96",
      accounts: ["0x" + PRIVATE_KEY]
    },
    sepolia: {
      url: "https://eth-sepolia.g.alchemy.com/v2/yoe6WqCO4_HbKg4NUgfkUXbPuZNKvDe3",
      accounts: ["0x" + PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: {
      polygonMumbai: POLYGONSCAN_API_KEY,
      goerli: GOERLISCAN_API_KEY,
      polygon: POLYGONSCAN_API_KEY,
      sepolia: SEPOLIASCAN_API_KEY
    }
  },
  mocha: {
    timeout: 100000000
  },
  abiExporter: {
    path: './data/abi',
    runOnCompile: false,
    clear: false,
    flat: false,
    only: [],
    except: [],
    spacing: 2,
    pretty: false,
    format: "json",
    filter: () => true,
    rename: undefined
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 100,
    enabled: true,
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: [],
  },
};

export default config;
