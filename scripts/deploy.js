const { ethers, upgrades } = require("hardhat");

async function main() {
  const OmnityPort = await ethers.getContractFactory("OmnityPortContract");
  const omnityPort = await upgrades.deployProxy(OmnityPort, ["0xef1A4FdB2D67350Ec777e75F76be08E3542b993f"]);
  await omnityPort.waitForDeployment();
  console.log("OmnityPort deployed to:", await omnityPort.getAddress());
}

main();
