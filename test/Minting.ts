import { ethers } from 'hardhat'
import chai, { expect } from 'chai'
import { beforeEach } from 'mocha'
import { Fantium721V1, FantiumMinterV1, FantiumMinterV1__factory } from '../typechain-types'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'

describe("Minting", () => {

    let nftContract: Fantium721V1
    let minterContract: FantiumMinterV1
    let owner: SignerWithAddress

    beforeEach(async () => {
        const [_owner] = await ethers.getSigners()
        owner = _owner
        console.log("Deploying contracts with the account:", owner.address)
        console.log("Account balance:", (await owner.getBalance()).toString())

        // Deploy the Fantium721V1 contract
        const Fantium721V1 = await ethers.getContractFactory("Fantium721V1")
        nftContract = (await Fantium721V1.deploy("FANtium", "FAN", 1)) as Fantium721V1
        await nftContract.deployed()

        // Deploy the minter contract
        const FantiumMinterFactory = await ethers.getContractFactory("FantiumMinterV1")
        minterContract = await FantiumMinterFactory.deploy(nftContract.address)
        await minterContract.deployed()

        // Set the minter contract as the minter for the Fantium721V1 contract
        await nftContract.updateMinterContract(minterContract.address)

        // Add a collection
        await nftContract.addCollection(
            "Test Collection",
            "Test",
            "https://test.com/",
            "0x0000000000000000000000000000000000000000",
            10,
            0,
            0,
            0,
        )

        // Add Owner to KYC list
        await minterContract.addAddressToKYC(owner.address);

        // Unpause collection
        await nftContract.toggleCollectionIsPaused(1)
    })

    it("Checks if contracts are deployed", async () => {
        expect(await nftContract.name()).to.equal("FANtium")
        expect(await nftContract.symbol()).to.equal("FAN")
        expect(await minterContract.fantium721Address()).to.equal(nftContract.address)
    })

    it("Checks if owner can add a collection", async () => {
        const collection = await nftContract.collections(1)
        expect(collection.maxInvocations).to.equal(10)
    })

    it("Checks if owner address is in KYC list", async () => {
        expect(await minterContract.isAddressKYCed(owner.address)).to.equal(true)
    })

    it("Checks if collection is unpaused", async () => {
        const collection = await nftContract.collections(1)
        expect(collection.paused).to.equal(false)
    })

    it("Checks if owner can mint a token", async () => {
        await minterContract.purchaseTo(owner.address, 1)
        expect(await nftContract.balanceOf(owner.address)).to.equal(1)
    })

    it("Check if removing address from KYC list disables minting capability", async () => {
        await minterContract.removeAddressFromKYC(owner.address);
        expect(await minterContract.isAddressKYCed(owner.address)).to.equal(false)

        await expect(minterContract.purchaseTo(owner.address, 1)).to.be.revertedWith("Address not KYCed")
    })

})

