import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition-ethers";
import { vars } from "hardhat/config";
const DEPLOY_PRI_KEY = vars.get("DEPLOY_PRI_KEY");
const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    bevm_mainnet: {
      url: `https://rpc-mainnet-1.bevm.io`,
      accounts: [DEPLOY_PRI_KEY],
    }
  }
};

export default config;
