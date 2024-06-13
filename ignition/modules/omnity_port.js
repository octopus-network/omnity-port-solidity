const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const ProtModule = buildModule("PortModule", (m) => {
  //param: routes chainkey address
  const port = m.contract("OmnityPortContract",[ "0x3E69F92D07d337789f238270EA904Cb55715657c"]); //chain key addr
  return { port };
});

module.exports = ProtModule;
