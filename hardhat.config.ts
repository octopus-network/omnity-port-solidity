import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition-ethers";
const config: HardhatUserConfig = {
  solidity: "0.8.19",
  networks: {
    sepolia: {
      url: `https://rpc-sepolia.rockx.com`,
      accounts: [`a04cb5e20654d72bfa3c5818bd5e64f554cfcda4fc19919401f200e7cfb1aaf9`]
    }

  }
};

export default config;
