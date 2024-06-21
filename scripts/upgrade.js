const { ethers, upgrades } = require("hardhat");

const PROXY = "0xea1213666aB92EbaC40e5887ca5EeB26237fC58d";

async function main() {
  const OmnityPort = await ethers.getContractFactory("OmnityPortContractV2");
  console.log("Upgrading OmnityPort...");
  const r = await upgrades.upgradeProxy(PROXY, OmnityPort);
  console.log("OmnityPort upgraded successfully address: ", await r.getAddress());
}

main();
