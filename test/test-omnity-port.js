const {expect} = require("chai");
const { ethers } = require("hardhat");

describe("Omnity Port Contract", function() {

    it("ctoken ", async function() {
        const [owner] = await ethers.getSigners();
        const omnity = await ethers.deployContract("OmnityPortContract");
        

    });
});