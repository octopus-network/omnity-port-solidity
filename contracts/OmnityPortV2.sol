// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./OmnityPort.sol";
contract OmnityPortContractV2 is OmnityPortContract {
    function testUpgrade() public pure returns (string memory) {
        return "upgrade sucess";
    }
}