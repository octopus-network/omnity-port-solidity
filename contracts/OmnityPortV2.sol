// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./OmnityPort.sol";
contract OmnityPortContractV2 is OmnityPortContract {
    uint256 public testValue;
    function setTestValue(uint256 v) public onlyOwner {
        testValue = v;
    }
    function testUpgrade() public view returns (string memory) {
        return "upgrade sucess";
    }
}