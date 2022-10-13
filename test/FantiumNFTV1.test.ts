import { ethers, upgrades } from 'hardhat'
import { expect } from 'chai'
import { beforeEach } from 'mocha'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { FantiumNFTV1 } from '../typechain-types/contracts/FantiumNFTV1'

describe("FANtium", () => {

    let nftContract: FantiumNFTV1
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
        nftContract = await upgrades.deployProxy(FantiumNFTV1, ["FANtium", "FAN", 1], { initializer: 'initialize' }) as FantiumNFTV1

        // Set Fantium address for primary sale
        await nftContract.updateFantiumPrimarySaleAddress(fantium.address)

        // Add a collection
        await nftContract.addCollection(
            "Test Collection",
            "Test",
            "https://test.com/",
            athlete.address,
            90,
            5,
            "silver",
        )

        // Add admin to KYC list
        await nftContract.addAddressToKYC(admin.address);

        // Unpause collection
        await nftContract.toggleCollectionIsPaused(1)

        // Set FANtium primary sale percentage
        // await nftContract.updateFantiumPrimaryMarketRoyaltyPercentage(50)
    })

    it("Checks if contracts are deployed with proper parameters", async () => {
        expect(await nftContract.name()).to.equal("FANtium")
        expect(await nftContract.symbol()).to.equal("FAN")

        const collection = await nftContract.collections(1)
        expect(collection.tier.maxInvocations).to.equal(1000)
        expect(collection.tier.name).to.equal("silver")
        expect(collection.tier.tournamentEarningPercentage).to.equal(20)
    })

    it("Checks if admin address is in KYC list", async () => {
        expect(await nftContract.isAddressKYCed(admin.address)).to.equal(true)
    })

    it("Check if removing address from KYC list disables minting capability", async () => {
        await nftContract.removeAddressFromKYC(admin.address);
        expect(await nftContract.isAddressKYCed(admin.address)).to.equal(false)
        await expect(nftContract.mint(admin.address, 1, { value: 100000000000000 })).to.be.revertedWith("Address not KYCed")
    })

    it("Checks if collection is unpaused", async () => {
        const collection = await nftContract.collections(1)
        expect(collection.paused).to.equal(false)
    })

    it("Checks if admin can mint a token", async () => {
        await nftContract.mint(admin.address, 1, { value: 100 })
        expect(await nftContract.balanceOf(admin.address)).to.equal(1)
    })

    it("Checks that admin cannot mint more than the max supply", async () => {
        await nftContract.mint(admin.address, 1, { value: 100 })
        expect(await nftContract.balanceOf(admin.address)).to.be.revertedWith("Maximum number of invocations reached")
    })

    it("Checks if fee is paid to Fantium", async () => {
        const balanceBefore = await fantium.getBalance()
        console.log("Balance before minting:", balanceBefore.toString())
        await nftContract.mint(admin.address, 1, { value: 100 })
        const balanceAfter = await fantium.getBalance()
        console.log("Balance after minting:", balanceAfter.toString())
        expect(balanceAfter.sub(balanceBefore)).to.equal(10)
    })

    it("Checks if fee is paid to athlete", async () => {
        const balanceBefore = await athlete.getBalance()
        console.log("Balance before minting:", balanceBefore.toString())
        await nftContract.mint(admin.address, 1, { value: 100000000000000 })
        const balanceAfter = await athlete.getBalance()
        console.log("Balance after minting:", balanceAfter.toString())
        expect(balanceAfter.sub(balanceBefore)).to.equal(90)
    })

    it("Checks if token URI is correct", async () => {
        await nftContract.mint(admin.address, 1, { value: 100000000000000 })
        const tokenURI = await nftContract.tokenURI(1000001)
        console.log("Token URI:", tokenURI)

        expect(tokenURI).to.equal("https://test.com/1000001")
    })


})

