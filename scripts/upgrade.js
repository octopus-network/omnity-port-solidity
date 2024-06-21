const { ethers, upgrades } = require("hardhat");

const PROXY = "0x29b416d48C84D99d0271c05ab74B49bb6D5549e6";
async function main() {
  const OmnityPort = await ethers.getContractFactory("OmnityPortContractV2");
  console.log("Upgrading OmnityPort...");
  const r = await upgrades.upgradeProxy(PROXY, OmnityPort);
  console.log("OmnityPort upgraded successfully address: ", await r.getAddress());
}

main();
