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
    let fan: SignerWithAddress

    beforeEach(async () => {
        const [_admin, _fantium, _athlete, _fan] = await ethers.getSigners()
        admin = _admin
        fantium = _fantium
        athlete = _athlete
        fan = _fan

        // Deploy the FantiumNFTV1 contract
        const FantiumNFTV1 = await ethers.getContractFactory("FantiumNFTV1")
        nftContract = await upgrades.deployProxy(FantiumNFTV1, ["FANtium", "FAN"], { initializer: 'initialize' }) as FantiumNFTV1

        // Set Fantium address for primary sale
        await nftContract.updateFantiumPrimarySaleAddress(fantium.address)
        await nftContract.updateFantiumSecondarySaleAddress(fantium.address)
        await nftContract.updateFantiumSecondaryMarketRoyaltyBPS(250)
        await nftContract.setNextCollectionId(1)

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
        expect(await nftContract.isAddressKYCed(fan.address)).to.equal(false)
        await nftContract.addAddressToKYC(fan.address)
        expect(await nftContract.isAddressKYCed(fan.address)).to.equal(true)

        expect(await nftContract.balanceOf(fan.address)).to.equal(0)
        
        await nftContract.toggleCollectionIsPaused(1)
        await nftContract.connect(fan).mint(fan.address, 1, { value: 100000000000000 })
        
        expect(await nftContract.balanceOf(fan.address)).to.equal(1)
    })

    it("3. Checks if Allowlist functionality works", async () => {
        expect(await nftContract.isAddressKYCed(fan.address)).to.equal(false)
        await nftContract.addAddressToKYC(fan.address) 
        expect(await nftContract.isAddressKYCed(fan.address)).to.equal(true)
        
        expect(await nftContract.isAddressOnAllowList(1, fan.address)).to.equal(false)
        await nftContract.addAddressToAllowList(1, fan.address)
        expect(await nftContract.isAddressOnAllowList(1, fan.address)).to.equal(true)
        
        expect(await nftContract.balanceOf(fan.address)).to.equal(0)
        await nftContract.connect(fan).mint(fan.address, 1, { value: 100000000000000 })
        expect(await nftContract.balanceOf(fan.address)).to.equal(1)
    })

    it("4. Checks if pausing works", async () => {
        await nftContract.addAddressToKYC(fan.address)
        
        expect((await nftContract.collections(1)).paused).to.equal(true)
        expect(nftContract.connect(fan).mint(fan.address, 1)).to.be.revertedWith("Purchases are paused and not on allow list")
       
        await nftContract.toggleCollectionIsPaused(1)
        expect((await nftContract.collections(1)).paused).to.equal(false)
    })

    it("5. Checks if admin can mint a token without being KYCed or Allowlisted", async () => {
        await nftContract.toggleCollectionIsPaused(1)
        await nftContract.mint(admin.address, 1, { value: 100 })
        expect(await nftContract.balanceOf(admin.address)).to.equal(1)
    })

    it("6. Checks that admin cannot mint more than the max supply", async () => {
        await nftContract.mint(admin.address, 1, { value: 100 })
        expect(await nftContract.balanceOf(admin.address)).to.be.revertedWith("Maximum number of invocations reached")
    })

    it("7. Checks if fee is paid to Fantium", async () => {
        const balanceBefore = await fantium.getBalance()
        console.log("Balance before minting:", balanceBefore.toString())
        await nftContract.mint(admin.address, 1, { value: 100 })
        const balanceAfter = await fantium.getBalance()
        console.log("Balance after minting:", balanceAfter.toString())
        expect(balanceAfter.sub(balanceBefore)).to.equal(10)
    })

    it("8. Checks if fee is paid to athlete", async () => {
        const balanceBefore = await athlete.getBalance()
        console.log("Balance before minting:", balanceBefore.toString())
        await nftContract.mint(admin.address, 1, { value: 100000000000000 })
        const balanceAfter = await athlete.getBalance()
        console.log("Balance after minting:", balanceAfter.toString())
        expect(balanceAfter.sub(balanceBefore)).to.equal(90)
    })

    it("9. Checks if token URI is correct", async () => {
        await nftContract.mint(admin.address, 1, { value: 100000000000000 })
        const tokenURI = await nftContract.tokenURI(1000001)
        console.log("Token URI:", tokenURI)

        expect(tokenURI).to.equal("https://test.com/1000001")
    })


})

