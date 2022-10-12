import { ethers, upgrades } from 'hardhat'
import { expect } from 'chai'
import { beforeEach } from 'mocha'
import { FantiumNFTV1 } from '../typechain-types/contracts/FantiumNFTV1'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'

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
        console.log("Minter proxy address: ", nftContract.address)

        console.log("Implementation address: ", await upgrades.erc1967.getImplementationAddress(nftContract.address))

        // await upgrades.upgradeProxy(minterContract, FantiumMinterFactory)
        // console.log("New implemnentation address:", await upgrades.erc1967.getImplementationAddress(minterContract.address))

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
        await nftContract.addAddressToKYC(admin.address);

        // Unpause collection
        await nftContract.toggleCollectionIsPaused(1)

        // Set FANtium primary sale percentage
        // await nftContract.updateFantiumPrimaryMarketRoyaltyPercentage(50)
    })

    it("Checks if contracts are deployed", async () => {
        expect(await nftContract.name()).to.equal("FANtium")
        expect(await nftContract.symbol()).to.equal("FAN")
    })

    it("Checks if admin can add a collection", async () => {
        const collection = await nftContract.collections(1)
        expect(collection.maxInvocations).to.equal(1)
    })

    it("Checks if admin address is in KYC list", async () => {
        expect(await nftContract.isAddressKYCed(admin.address)).to.equal(true)
    })

    it("Check if removing address from KYC list disables minting capability", async () => {
        await nftContract.removeAddressFromKYC(admin.address);
        expect(await nftContract.isAddressKYCed(admin.address)).to.equal(false)
        await expect(nftContract.purchaseTo(admin.address, 1, { value: 100 })).to.be.revertedWith("Address not KYCed")
    })

    it("Checks if collection is unpaused", async () => {
        const collection = await nftContract.collections(1)
        expect(collection.paused).to.equal(false)
    })

    it("Checks if admin can mint a token", async () => {
        await nftContract.purchaseTo(admin.address, 1, { value: 100 })
        expect(await nftContract.balanceOf(admin.address)).to.equal(1)
    })

    it("Checks that admin cannot mint more than the max supply", async () => {
        await nftContract.purchaseTo(admin.address, 1, { value: 100 })
        expect(await nftContract.balanceOf(admin.address)).to.be.revertedWith("Maximum number of invocations reached")
    })

    it("Checks if fee is paid to Fantium", async () => {
        const balanceBefore = await fantium.getBalance()
        console.log("Balance before minting:", balanceBefore.toString())
        await nftContract.purchaseTo(admin.address, 1, { value: 100 })
        const balanceAfter = await fantium.getBalance()
        console.log("Balance after minting:", balanceAfter.toString())
        expect(balanceAfter.sub(balanceBefore)).to.equal(10)
    })

    it("Checks if fee is paid to athlete", async () => {
        const balanceBefore = await athlete.getBalance()
        console.log("Balance before minting:", balanceBefore.toString())
        await nftContract.purchaseTo(admin.address, 1, { value: 100 })
        const balanceAfter = await athlete.getBalance()
        console.log("Balance after minting:", balanceAfter.toString())
        expect(balanceAfter.sub(balanceBefore)).to.equal(90)
    })

    it("Checks if token URI is correct", async () => {
        await nftContract.purchaseTo(admin.address, 1, { value: 100 })
        const tokenURI = await nftContract.tokenURI(1000001)
        console.log("Token URI:", tokenURI)

        expect(tokenURI).to.equal("https://test.com/1000001")
    })


})

