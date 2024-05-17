const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const TokenModule = buildModule("TokenModule", (m) => {
  const token = m.contract("OmnityPortContract",["0x033965f4d0c44b21c3694a933f91fb0ca5b05c114264aa3de8fd00f8172bfda629", "0x4558e67a18d6Baa4EF91dc4724a181c80080207E", "sepolia-test"]);

  return { token };
});

module.exports = TokenModule;
