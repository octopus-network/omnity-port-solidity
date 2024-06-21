// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenContract is ERC20, Ownable {
    uint8 private _decimals;
    string private _name;
    string private _symbol;

    constructor(
        address initialOwner,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_) Ownable(initialOwner) {
        _decimals = decimals_;
        _symbol = symbol_;
        _name = name_;
    }

    function updateSymbol(string memory symbol_) public onlyOwner {
        _symbol = symbol_;
    }

    function updateName(string memory name_) public onlyOwner {
        _name = name_;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address receiver, uint256 amount) public onlyOwner {
        _mint(receiver, amount);
    }

    function burn(address owner, uint256 amount) public onlyOwner {
        _burn(owner, amount);
    }
}
