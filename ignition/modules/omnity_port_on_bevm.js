const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const TokenModule = buildModule("TokenModule", (m) => {
  //minerPubkey, minerAddress( the evm_route chainkey address), chain_id 
  const token = m.contract("OmnityPortContract",["0x033965f4d0c44b21c3694a933f91fb0ca5b05c114264aa3de8fd00f8172bfda629", "0xa16dF97FAca7Fba157224761BF9A79C985a25973", "bevm"]);
  return { token };
});

module.exports = TokenModule;
