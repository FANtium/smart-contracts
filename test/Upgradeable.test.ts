import { ethers, upgrades } from 'hardhat'
import { expect } from 'chai'
import { beforeEach } from 'mocha'
import { FantiumMinterV1 } from '../typechain-types'
import { FantiumNFTV1 } from '../typechain-types/contracts/FantiumNFTV1'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'

describe("FANtium", () => {

    let nftContract: FantiumNFTV1
    let minterContract: FantiumMinterV1
    let admin: SignerWithAddress
    let fantium: SignerWithAddress
    let athlete: SignerWithAddress

    beforeEach(async () => {
        const [_admin, _fantium, _athlete] = await ethers.getSigners()
        admin = _admin
        fantium = _fantium
        athlete = _athlete

        // Deploy the FantiumNFTV1 contract
        const FantiumNFTV1 = await ethers.getContractFactory("FantiumNFTV1")
        nftContract = (await FantiumNFTV1.deploy("FANtium", "FAN", 1)) as FantiumNFTV1
        await nftContract.deployed()

        // Deploy the minter contract
        const FantiumMinterFactory = await ethers.getContractFactory("FantiumMinterV1")
        minterContract = await upgrades.deployProxy(FantiumMinterFactory, [nftContract.address], { initializer: 'initialize' }) as FantiumMinterV1
        console.log("Minter proxy address: ", minterContract.address)

        console.log("Implementation address: ", await upgrades.erc1967.getImplementationAddress(minterContract.address))

        await upgrades.upgradeProxy(minterContract, FantiumMinterFactory)
        console.log("New implemnentation address:", await upgrades.erc1967.getImplementationAddress(minterContract.address))

        // Set the minter contract as the minter for the FantiumNFTV1 contract
        await nftContract.updateMinterContract(minterContract.address)

        // Set Fantium address for primary sale
        await nftContract.updateFantiumPrimarySaleAddress(fantium.address)

        // Add a collection
        await nftContract.addCollection(
            "Test Collection",
            "Test",
            "https://test.com/",
            athlete.address,
            1,
            100,
            90,
            10,
        )

        // Add admin to KYC list
        await minterContract.addAddressToKYC(admin.address);

        // Unpause collection
        await nftContract.toggleCollectionIsPaused(1)

        // Set FANtium primary sale percentage
        // await nftContract.updateFantiumPrimaryMarketRoyaltyPercentage(50)
    })

    it("Checks if contracts are deployed", async () => {
        expect(await nftContract.name()).to.equal("FANtium")
        expect(await nftContract.symbol()).to.equal("FAN")

        expect(await minterContract.fantium721Address()).to.equal(nftContract.address)
    })

    it("Checks if admin can add a collection", async () => {
        const collection = await nftContract.collections(1)
        expect(collection.maxInvocations).to.equal(1)
    })

    it("Checks if admin address is in KYC list", async () => {
        expect(await minterContract.isAddressKYCed(admin.address)).to.equal(true)
    })

    it("Check if removing address from KYC list disables minting capability", async () => {
        await minterContract.removeAddressFromKYC(admin.address);
        expect(await minterContract.isAddressKYCed(admin.address)).to.equal(false)
        await expect(minterContract.purchaseTo(admin.address, 1, { value: 100 })).to.be.revertedWith("Address not KYCed")
    })

    it("Checks if collection is unpaused", async () => {
        const collection = await nftContract.collections(1)
        expect(collection.paused).to.equal(false)
    })

    it("Checks if admin can mint a token", async () => {
        await minterContract.purchaseTo(admin.address, 1, { value: 100 })
        expect(await nftContract.balanceOf(admin.address)).to.equal(1)
    })

    it("Checks that admin cannot mint more than the max supply", async () => {
        await minterContract.purchaseTo(admin.address, 1, { value: 100 })
        expect(await nftContract.balanceOf(admin.address)).to.be.revertedWith("Maximum number of invocations reached")
    })

    it("Checks if fee is paid to Fantium", async () => {
        const balanceBefore = await fantium.getBalance()
        console.log("Balance before minting:", balanceBefore.toString())
        await minterContract.purchaseTo(admin.address, 1, { value: 100 })
        const balanceAfter = await fantium.getBalance()
        console.log("Balance after minting:", balanceAfter.toString())
        expect(balanceAfter.sub(balanceBefore)).to.equal(10)
    })

    it("Checks if fee is paid to athlete", async () => {
        const balanceBefore = await athlete.getBalance()
        console.log("Balance before minting:", balanceBefore.toString())
        await minterContract.purchaseTo(admin.address, 1, { value: 100 })
        const balanceAfter = await athlete.getBalance()
        console.log("Balance after minting:", balanceAfter.toString())
        expect(balanceAfter.sub(balanceBefore)).to.equal(90)
    })

    it("Checks if token URI is correct", async () => {
        await minterContract.purchaseTo(admin.address, 1, { value: 100 })
        const tokenURI = await nftContract.tokenURI(1000001)
        console.log("Token URI:", tokenURI)

        expect(tokenURI).to.equal("https://test.com/1000001")
    })


})

