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
    bevm: {
      url: `https://rpc-mainnet-1.bevm.io`,
      accounts: [DEPLOY_PRI_KEY],
    },
    bitlayer: {
	    url:`https://rpc.bitlayer.org`,
	    accounts: [DEPLOY_PRI_KEY],
    },
    bob: {
	    url:`https://rpc.gobob.xyz`,
	    accounts: [DEPLOY_PRI_KEY],
    },
    bsquared: {
	    url:`https://mainnet.b2-rpc.com`,
	    accounts: [DEPLOY_PRI_KEY],
    },
    xlayer: {
	    url:`https://rpc.xlayer.tech`,
	    accounts: [DEPLOY_PRI_KEY],
    },
    merlin: {
	    url:`https://rpc.merlinchain.io`,
	    accounts: [DEPLOY_PRI_KEY],
    }
  }
};

export default config;
