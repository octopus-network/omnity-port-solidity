const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const ProtModule = buildModule("PortModule", (m) => {
  //param: routes chainkey address
  const port = m.contract("OmnityPortContract",[ "0x44b2f53aA07A14aD186a3fCB44b53E0d7F398812"]); //chainkey addr
  return { port };
});

module.exports = ProtModule;
