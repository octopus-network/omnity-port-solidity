const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const ProtModule = buildModule("PortModule", (m) => {
  //param: routes chainkey address
  const port = m.contract("OmnityPortContract",[ "0xa16dF97FAca7Fba157224761BF9A79C985a25973"]);
  return { port };
});

module.exports = ProtModule;
