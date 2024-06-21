import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition-ethers";
import "@openzeppelin/hardhat-upgrades";

import { vars } from "hardhat/config";
const DEPLOY_PRI_KEY = vars.get("DEPLOY_PRI_KEY");
const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings:{
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    sepolia: {
      url: `https://rpc-sepolia.rockx.com`,
      accounts: [DEPLOY_PRI_KEY],
    },
    bevm_testnet: {
      url: `https://testnet.bevm.io`,
      accounts: [DEPLOY_PRI_KEY],
    },
    bitlayer_testnet: {
	url:`https://testnet-rpc.bitlayer.org`,
	accounts: [DEPLOY_PRI_KEY],
    }
  }
};

export default config;
