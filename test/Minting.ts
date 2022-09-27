import { ethers } from 'hardhat'
import chai, { expect } from 'chai'

describe("Minting", () => {
    // it("Should mint tokens", async () => {
    //     const [owner] = await ethers.getSigners()
    //     const Token = await ethers.getContractFactory("Token")
    //     const token = await Token.deploy()
    //     await token.deployed()
    //     await token.mint(owner.address, 1000)
    //     expect(await token.balanceOf(owner.address)).to.equal(1000)
    // })

    it("Deployment should assign the total supply of tokens to the owner", async function () {
        const [owner] = await ethers.getSigners();

        const Token = await ethers.getContractFactory("Token");

        const hardhatToken = await Token.deploy();

        const ownerBalance = await hardhatToken.balanceOf(owner.address);
        expect(await hardhatToken.totalSupply()).to.equal(ownerBalance);
    })
})

