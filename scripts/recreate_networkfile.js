
const { ethers, upgrades } = require("hardhat");

async function main() {
  const OmnityPort = await ethers.getContractFactory("OmnityPortContract");
  console.log("recreate network file ...");
  const r = await upgrades.forceImport(process.env.PROXY, OmnityPort);
  console.log("OmnityPort upgraded successfully address: ", await r.getAddress());
}

main();