import { ethers, upgrades } from 'hardhat'
import { expect } from 'chai'
import { beforeEach } from 'mocha'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { FantiumNFTV1 } from '../typechain-types/contracts/FantiumNFTV1'
import { FantiumMinterV1 } from '../typechain-types/contracts/FantiumMinterV1'

describe("FANtiumNFT", () => {

    let nftContract: FantiumNFTV1
    let minterContract: FantiumMinterV1
    let rogueMinterContract: FantiumMinterV1
    let defaultAdmin: SignerWithAddress
    let platformManager: SignerWithAddress
    let fantium: SignerWithAddress
    let athlete: SignerWithAddress
    let fan: SignerWithAddress

    beforeEach(async () => {
        const [_defaultAdmin, _platformManager, _fantium, _athlete, _fan] = await ethers.getSigners()
        defaultAdmin = _defaultAdmin
        platformManager = _platformManager
        fantium = _fantium
        athlete = _athlete
        fan = _fan

        // Deploy the FantiumNFTV1 contract
        const FantiumNFTV1 = await ethers.getContractFactory("FantiumNFTV1")
        nftContract = await upgrades.deployProxy(FantiumNFTV1, ["FANtium", "FAN"], { initializer: 'initialize' }) as FantiumNFTV1

        // Deploy the FantiumMinterV1 contract
        const FantiumMinterV1 = await ethers.getContractFactory("FantiumMinterV1")
        minterContract = await upgrades.deployProxy(FantiumMinterV1, [], { initializer: 'initialize' }) as FantiumMinterV1

        // Set the FantiumMinterV1 contract as the minter for the FantiumNFTV1 contract
        await nftContract.updateFantiumMinterAddress(minterContract.address)

        // Set the FantiumNFTV1 contract as the nft contract for the FantiumMinterV1 contract
        await minterContract.updateFantiumNFTAddress(nftContract.address)

        // Set Fantium address for primary sale
        await nftContract.updateFantiumPrimarySaleAddress(fantium.address)
        await nftContract.updateFantiumSecondarySaleAddress(fantium.address)
        await nftContract.updateFantiumSecondaryMarketRoyaltyBPS(250)

        await nftContract.updateTiers("bronze", 10, 10000, 10)
        await nftContract.updateTiers("silver", 100, 1000, 20)
        await nftContract.updateTiers("gold", 1000, 100, 30)

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
    })

    it("1. Checks if contracts are deployed with proper parameters", async () => {
        expect(await nftContract.name()).to.equal("FANtium")
        expect(await nftContract.symbol()).to.equal("FAN")

        const collection = await nftContract.collections(1)
        expect(collection.tier.maxInvocations).to.equal(1000)
        expect(collection.tier.name).to.equal("silver")
        expect(collection.tier.tournamentEarningPercentage).to.equal(20)
    })

    it("2. Checks if KYC funtionality works", async () => {
        expect(await minterContract.isAddressKYCed(fan.address)).to.equal(false)
        await minterContract.addAddressToKYC(fan.address)
        expect(await minterContract.isAddressKYCed(fan.address)).to.equal(true)

        expect(await nftContract.balanceOf(fan.address)).to.equal(0)

        await nftContract.toggleCollectionIsPaused(1)
        await minterContract.connect(fan).mint(fan.address, 1, { value: 100000000000000 })

        expect(await nftContract.balanceOf(fan.address)).to.equal(1)
    })

    it("3. Checks if Allowlist functionality works", async () => {
        expect(await minterContract.isAddressKYCed(fan.address)).to.equal(false)
        await minterContract.addAddressToKYC(fan.address)
        expect(await minterContract.isAddressKYCed(fan.address)).to.equal(true)

        expect(await minterContract.isAddressOnAllowList(1, fan.address)).to.equal(false)
        await minterContract.addAddressToAllowList(1, fan.address)
        expect(await minterContract.isAddressOnAllowList(1, fan.address)).to.equal(true)

        expect(await nftContract.balanceOf(fan.address)).to.equal(0)
        await minterContract.connect(fan).mint(fan.address, 1, { value: 100000000000000 })
        expect(await nftContract.balanceOf(fan.address)).to.equal(1)
    })

    it("4. Checks if pausing works", async () => {
        await minterContract.addAddressToKYC(fan.address)

        expect((await nftContract.collections(1)).paused).to.equal(true)
        expect(minterContract.connect(fan).mint(fan.address, 1)).to.be.revertedWith("Purchases are paused and not on allow list")

        await nftContract.toggleCollectionIsPaused(1)
        expect((await nftContract.collections(1)).paused).to.equal(false)
    })

    it("5. Checks if admin can mint a token without being KYCed or Allowlisted", async () => {
        await nftContract.toggleCollectionIsPaused(1)
        await minterContract.mint(defaultAdmin.address, 1, { value: 100 })
        expect(await nftContract.balanceOf(defaultAdmin.address)).to.equal(1)
    })

    it("6. Checks that admin cannot mint more than the max supply", async () => {
        await minterContract.mint(defaultAdmin.address, 1, { value: 100 })
        expect(await nftContract.balanceOf(defaultAdmin.address)).to.be.revertedWith("Maximum number of invocations reached")
    })

    it("7. Checks if fee is paid to Fantium", async () => {
        const balanceBefore = await fantium.getBalance()
        console.log("Balance before minting:", balanceBefore.toString())
        await minterContract.mint(defaultAdmin.address, 1, { value: 100 })
        const balanceAfter = await fantium.getBalance()
        console.log("Balance after minting:", balanceAfter.toString())
        expect(balanceAfter.sub(balanceBefore)).to.equal(10)
    })

    it("8. Checks if fee is paid to athlete", async () => {
        const balanceBefore = await athlete.getBalance()
        console.log("Balance before minting:", balanceBefore.toString())
        await minterContract.mint(defaultAdmin.address, 1, { value: 100000000000000 })
        const balanceAfter = await athlete.getBalance()
        console.log("Balance after minting:", balanceAfter.toString())
        expect(balanceAfter.sub(balanceBefore)).to.equal(90)
    })

    it("9. Checks if token URI is correct", async () => {
        await minterContract.mint(defaultAdmin.address, 1, { value: 100000000000000 })
        const tokenURI = await nftContract.tokenURI(1000001)
        console.log("Token URI:", tokenURI)

        expect(tokenURI).to.equal("https://test.com/1000001")
    })

    it("10. Checks if 0 address for NFT contract in Minter contract blocks minting on Minter contract", async () => {
        await minterContract.updateFantiumNFTAddress(ethers.constants.AddressZero)
        expect(minterContract.mint(defaultAdmin.address, 1, { value: 100 })).to.be.revertedWith("Fantium NFT not set")
    })

    it("11. Checks if 0 address for Minter contract in NFT contract blocks minting on NFT contract", async () => {
        await nftContract.updateFantiumMinterAddress(ethers.constants.AddressZero)
        expect(minterContract.mint(defaultAdmin.address, 1, { value: 100 })).to.be.revertedWith("Fantium Minter not set")
    })

    it("Checks if rogue minter contract cannot mint on NFT contract", async () => {
        // Deploy the FantiumMinterV1 contract
        const FantiumMinterV1 = await ethers.getContractFactory("FantiumMinterV1")
        rogueMinterContract = await upgrades.deployProxy(FantiumMinterV1, [], { initializer: 'initialize' }) as FantiumMinterV1
        // Set the FantiumNFTV1 contract as the nft contract for the RogueFantiumMinterV1 contract
        await rogueMinterContract.updateFantiumNFTAddress(nftContract.address)

        expect(rogueMinterContract.mint(defaultAdmin.address, 1, { value: 100 })).to.be.revertedWith("Only assigned minter")
    })
})

