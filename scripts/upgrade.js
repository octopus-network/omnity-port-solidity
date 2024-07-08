const { ethers, upgrades } = require("hardhat");

async function main() {
  const OmnityPort = await ethers.getContractFactory("OmnityPortContract");
  console.log("Upgrading OmnityPort...");
  const r = await upgrades.upgradeProxy(process.env.PROXY, OmnityPort);
  console.log("OmnityPort upgraded successfully address: ", await r.getAddress());
}

main();
