const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const ProtModule = buildModule("PortModule", (m) => {
  //param: routes chainkey address
  const port = m.contract("OmnityPortContract",[ "0x30dbCA3314c49e4c59A9815CF87DDC7E5205C327"]); //chain key addr
  return { port };
});

module.exports = ProtModule;