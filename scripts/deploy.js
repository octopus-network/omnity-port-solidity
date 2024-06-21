const { ethers, upgrades } = require("hardhat");

async function main() {
  const OmnityPort = await ethers.getContractFactory("OmnityPortContract");
  const omnityPort = await upgrades.deployProxy(OmnityPort, ["0x30dbCA3314c49e4c59A9815CF87DDC7E5205C327"]);
  await omnityPort.waitForDeployment();
  console.log("OmnityPort deployed to:", await omnityPort.getAddress());
}

main();