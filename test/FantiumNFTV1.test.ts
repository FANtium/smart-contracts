import { ethers, upgrades } from 'hardhat'
import { expect } from 'chai'
import { beforeEach } from 'mocha'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { FantiumNFTV1 } from '../typechain-types/contracts/FantiumNFTV1'
import { Mock20 } from '../typechain-types/contracts/Mock20'

describe("FANtiumNFT", () => {

    let nftContract: FantiumNFTV1
    let erc20Contract: Mock20
    let defaultAdmin: SignerWithAddress
    let platformManager: SignerWithAddress
    let kycManager: SignerWithAddress
    let fantium: SignerWithAddress
    let athlete: SignerWithAddress
    let fan: SignerWithAddress
    let other: SignerWithAddress

    const primarySalePercentage = 90
    const secondarySalePercentage = 5
    const maxInvocations = 100
    const priceInWei = 100
    const earningsSplit = 10

    beforeEach(async () => {
        const [_defaultAdmin, _platformManager, _kycManager, _fantium, _athlete, _fan, _other] = await ethers.getSigners()
        defaultAdmin = _defaultAdmin
        platformManager = _platformManager
        kycManager = _kycManager
        fantium = _fantium
        athlete = _athlete
        fan = _fan
        other = _other

        const Mock20 = await ethers.getContractFactory("Mock20")
        erc20Contract = await Mock20.connect(fan).deploy() as Mock20

        const FantiumNFTV1 = await ethers.getContractFactory("FantiumNFTV1")
        nftContract = await upgrades.deployProxy(FantiumNFTV1, ["FANtium", "FAN", defaultAdmin.address], { initializer: 'initialize' }) as FantiumNFTV1

        // set Roles
        await nftContract.connect(defaultAdmin).grantRole(await nftContract.PLATFORM_MANAGER_ROLE(), platformManager.address)
        await nftContract.connect(defaultAdmin).grantRole(await nftContract.KYC_MANAGER_ROLE(), kycManager.address)

        // set Fantium address for primary sale
        await nftContract.connect(platformManager).updateFantiumPrimarySaleAddress(fantium.address)
        await nftContract.connect(platformManager).updateFantiumSecondarySaleAddress(fantium.address)
        await nftContract.connect(platformManager).updateFantiumSecondaryMarketRoyaltyBPS(250)

        // set payment token
        await nftContract.connect(platformManager).updatePaymentToken(erc20Contract.address)

        // add first collection
        await nftContract.connect(platformManager).addCollection(
            athlete.address,
            primarySalePercentage,
            secondarySalePercentage,
            maxInvocations,
            priceInWei,
            earningsSplit
        )

        // set contract base URI
        await nftContract.connect(platformManager).updateBaseURI("https://contract.com/")

        // set erc20 token address
        await nftContract.connect(platformManager).updatePaymentToken(erc20Contract.address)
    })


    /// CONTRACT PARAMETERS

    it("checks contract parameters", async () => {
        // name & symbol
        expect(await nftContract.name()).to.equal("FANtium")
        expect(await nftContract.symbol()).to.equal("FAN")

        // roles
        expect(await nftContract.hasRole(await nftContract.DEFAULT_ADMIN_ROLE(), defaultAdmin.address)).to.equal(true)
        expect(await nftContract.hasRole(await nftContract.PLATFORM_MANAGER_ROLE(), platformManager.address)).to.equal(true)
        expect(await nftContract.hasRole(await nftContract.KYC_MANAGER_ROLE(), kycManager.address)).to.equal(true)

        // addresses
        expect(await nftContract.fantiumPrimarySalesAddress()).to.equal(fantium.address)
        expect(await nftContract.fantiumSecondarySalesAddress()).to.equal(fantium.address)

        // royalties
        expect(await nftContract.fantiumSecondarySalesBPS()).to.equal(250)
    })


    /// CONTRACT PAUSING

    it("checks that PLATFORM MANAGER can pause contract", async () => {
        // pause contract
        await nftContract.connect(platformManager).updateContractPaused(true)

        // check contract is paused
        expect(await nftContract.paused()).to.equal(true)
    })


    /// KYC

    it("checks that KYC MANAGER can add to KYC", async () => {
        // check status of fan address
        expect(await nftContract.isAddressKYCed(fan.address)).to.equal(false)

        // add fan address to KYC
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        expect(await nftContract.isAddressKYCed(fan.address)).to.equal(true)
    })

    it("checks that KYC MANAGER can remove from KYC", async () => {
        // check status of fan address
        expect(await nftContract.isAddressKYCed(fan.address)).to.equal(false)

        // add fan address to KYC
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        expect(await nftContract.isAddressKYCed(fan.address)).to.equal(true)

        // remove fan address from KYC
        await nftContract.connect(kycManager).removeAddressFromKYC(fan.address)
        expect(await nftContract.isAddressKYCed(fan.address)).to.equal(false)
    })


    /// ALLOW LIST

    it("checks that PLATFORM MANAGER can add to Allowlist", async () => {
        expect(await nftContract.collectionIdToAllowList(1, fan.address)).to.equal(0)
        await nftContract.connect(platformManager).addAddressToAllowListWithAllocation(1, fan.address, 1)
        expect(await nftContract.collectionIdToAllowList(1, fan.address)).to.equal(1)
    })

    it("checks that PLATFORM MANAGER can remove completely from Allowlist", async () => {
        expect(await nftContract.collectionIdToAllowList(1, fan.address)).to.equal(0)
        // add fan address to allowlist with 2 allocations
        await nftContract.connect(platformManager).addAddressToAllowListWithAllocation(1, fan.address, 2)
        expect(await nftContract.collectionIdToAllowList(1, fan.address)).to.equal(2)

        // remove fan address from allowlist completely
        await nftContract.connect(platformManager).reduceAllowListAllocation(1, fan.address, true)
        expect(await nftContract.collectionIdToAllowList(1, fan.address)).to.equal(0)
    })

    it("checks that PLATFORM MANAGER can remove partially from Allowlist", async () => {
        expect(await nftContract.collectionIdToAllowList(1, fan.address)).to.equal(0)
        // add fan address to allowlist with 2 allocations
        await nftContract.connect(platformManager).addAddressToAllowListWithAllocation(1, fan.address, 2)
        expect(await nftContract.collectionIdToAllowList(1, fan.address)).to.equal(2)

        // reduce fan address allocation by 1
        await nftContract.connect(platformManager).reduceAllowListAllocation(1, fan.address, false)
        expect(await nftContract.collectionIdToAllowList(1, fan.address)).to.equal(1)
    })


    /// MINTING

    it("checks that FAN cannot mint if NOT kyced", async () => {
        // check status of fan address
        expect(await nftContract.isAddressKYCed(fan.address)).to.equal(false)

        // ty to mint
        await expect(nftContract.connect(fan).mint(1, priceInWei)).to.be.revertedWith("Address is not KYCed");
    })

    it("checks that FAN cannot mint if kyced & NOT on allowlist & collection is not activated", async () => {
        // add fan address to KYC
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)

        // check if fan can mint
        await expect(nftContract.connect(fan).mint(1, priceInWei)).to.be.revertedWith("Collection is paused");
    })

    it("checks that FAN cannot mint if kyced & on allowlist & collection activated and collection minting paused & price is NOT correct (too low)", async () => {
        // add fan address to KYC
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        // add fan address to allowlist with 1 allocations
        await nftContract.connect(platformManager).addAddressToAllowListWithAllocation(1, fan.address, 1)
        // activate collection
        await nftContract.connect(platformManager).toggleCollectionActivated(1)

        // check if fan can mint
        await expect(nftContract.connect(fan).mint(1, priceInWei)).to.be.revertedWith("Incorrect amount sent");
    })

    it("checks that FAN can mint if kyced & on allowlist & collection minting paused & price is correct", async () => {
        // add fan address to KYC
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        // add fan address to allowlist with 1 allocation
        await nftContract.connect(platformManager).addAddressToAllowListWithAllocation(1, fan.address, 1)
        await nftContract.connect(platformManager).toggleCollectionActivated(1)
        // // check if fan can mint
        await nftContract.connect(fan).mint(1, priceInWei);

        // // check fan balance
        expect(await nftContract.balanceOf(fan.address)).to.equal(1);
    })

    it("checks that FAN cannot mint if kyced & on allowlist & collection minting paused & price is correct & allowlist allocation is used up", async () => {
        // add fan address to KYC
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        // add fan address to allowlist with 1 allocation
        await nftContract.connect(platformManager).addAddressToAllowListWithAllocation(1, fan.address, 1)

        // activate collection
        await nftContract.connect(platformManager).toggleCollectionActivated(1)

        // // check if fan can mint
        await nftContract.connect(fan).mint(1, priceInWei);

        // // check fan balance
        expect(await nftContract.balanceOf(fan.address)).to.equal(1);
        // // check if fan can mint again
        await expect(nftContract.connect(fan).mint(1, priceInWei)).to.be.revertedWith("Minting is paused");
    })

    it("checks that FAN CAN mint if kyced & collection minting is & price is correct", async () => {
        // add fan address to KYC
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        // unpause collection minting
        await nftContract.connect(platformManager).toggleCollectionIsPaused(1)
        await nftContract.connect(platformManager).toggleCollectionActivated(1)
        // check if fan can mint
        await nftContract.connect(fan).mint(1, priceInWei);

        // check fan balance
        expect(await nftContract.balanceOf(fan.address)).to.equal(1);
    })

    /// PRIMARY SALE SPLIT

    it("checks that ATHLETE primary sales split is correct", async () => {
        // check athlete balance
        const balanceBefore = await erc20Contract.balanceOf(athlete.address)//await athlete.getBalance()

        // approve nft contract to spend Mock20
        await erc20Contract.connect(fan).approve(nftContract.address, priceInWei)

        console.log(await erc20Contract.balanceOf(fan.address))

        console.log(await nftContract.getPrimaryRevenueSplits(1, priceInWei))

        // mint NFT
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        await nftContract.connect(platformManager).toggleCollectionActivated(1)
        await nftContract.connect(platformManager).toggleCollectionIsPaused(1)
        await nftContract.connect(fan).mint(1, priceInWei);
        // check athlete balance after mint
        const balanceAfter = await erc20Contract.balanceOf(athlete.address)

        expect(balanceAfter.sub(balanceBefore)).to.equal(90)
    })

    it("checks that FANtium primary sales split is correct", async () => {
        // check FANtium balance
        const balanceBefore = await erc20Contract.balanceOf(fantium.address)

        // approve nft contract to spend Mock20
        await erc20Contract.connect(fan).approve(nftContract.address, priceInWei)

        // mint NFT
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        await nftContract.connect(platformManager).toggleCollectionActivated(1)
        await nftContract.connect(platformManager).toggleCollectionIsPaused(1)
        await nftContract.connect(fan).mint(1, priceInWei);
        // check FANtium balance after mint
        const balanceAfter = await erc20Contract.balanceOf(fantium.address)

        expect(balanceAfter.sub(balanceBefore)).to.equal(10)
    })


    /// ADD COLLECTION

    it("checks that OTHER cannot add collection if NOT PLATFORM MANAGER", async () => {
        await expect(nftContract.connect(other)
            .addCollection(
                athlete.address,
                90,
                5,
                100,
                10000,
                10
            )).to.be.revertedWith('AccessControl: account 0x976ea74026e726554db657fa54763abd0c3a0aa9 is missing role 0xab538675bf961a344c31ab0f84b867b850736e871cc7bf3055ce65100abe02ea')
    })

    it("checks that PLATFORM MANAGER cannot add collections with 0x0 athlete address", async () => {
        await expect(nftContract.connect(platformManager)
            .addCollection(
                ethers.constants.AddressZero,
                90,
                5,
                100,
                10000,
                10
            )).to.be.revertedWith('Invalid address')
    })

    /// COLLECTION UPDATES

    it("checks that PLATFORM MANAGER cannot update athlete address with 0x0 address", async () => {
        // try to update collection athlete address
        await expect(nftContract.connect(platformManager).updateCollectionAthleteAddress(1, ethers.constants.AddressZero)).to.be.revertedWith("Invalid address");
    })

    it("checks that PLATFORM MANAGER can toggle collection isMintingPause", async () => {
        // check collection is paused
        expect(await (await nftContract.collections(1)).isMintingPaused).to.equal(true)

        // toggle collection  paused
        await nftContract.connect(platformManager).toggleCollectionIsPaused(1)
        // check collection minting is unPaused
        expect(await (await nftContract.collections(1)).isMintingPaused).to.equal(false)

        // toggle collection is paused
        await nftContract.connect(platformManager).toggleCollectionIsPaused(1)
        // check collection is paused
        expect(await (await nftContract.collections(1)).isMintingPaused).to.equal(true)
    })

    it("checks that PLATFORM MANAGER can toggle isActivated", async () => {
        // check collection is paused
        expect(await (await nftContract.collections(1)).isActivated).to.equal(false)

        // update collection pause status
        await nftContract.connect(platformManager).toggleCollectionActivated(1)

        // check collection is unPaused
        expect(await (await nftContract.collections(1)).isActivated).to.equal(true)
    })

    it("checks that ATHLETE can toggle their collection isMintingPause", async () => {
        // check collection is paused
        expect(await (await nftContract.collections(1)).isMintingPaused).to.equal(true)

        // toggle collection  paused
        await nftContract.connect(athlete).toggleCollectionIsPaused(1)
        // check collection minting is unPaused
        expect(await (await nftContract.collections(1)).isMintingPaused).to.equal(false)

        // toggle collection is paused
        await nftContract.connect(athlete).toggleCollectionIsPaused(1)
        // check collection is paused
        expect(await (await nftContract.collections(1)).isMintingPaused).to.equal(true)
    })

    it("checks that PLATFORM MANAGER can update collection athlete address", async () => {
        // check collection athlete address
        expect(await (await nftContract.collections(1)).athleteAddress).to.equal(athlete.address)

        // update collection athlete address
        await nftContract.connect(platformManager).updateCollectionAthleteAddress(1, other.address)

        // check collection athlete address
        expect(await (await nftContract.collections(1)).athleteAddress).to.equal(other.address)
    })

    it("checks that PLATFROM MANAGER can update athlete primary market royalty percentage", async () => {
        // check athlete primary market royalty percentage
        expect(await (await nftContract.collections(1)).athletePrimarySalesPercentage).to.equal(90)

        // update athlete primary market royalty percentage
        await nftContract.connect(platformManager).updateCollectionAthletePrimaryMarketRoyaltyPercentage(1, 50)

        // check athlete primary market royalty percentage
        expect(await (await nftContract.collections(1)).athletePrimarySalesPercentage).to.equal(50)
    })

    it("checks that PLATFROM MANAGER can update athlete secondary market royalty percentage", async () => {
        // check athlete secondary market royalty percentage
        expect(await (await nftContract.collections(1)).athleteSecondarySalesPercentage).to.equal(5)

        // update athlete secondary market royalty percentage
        await nftContract.connect(platformManager).updateCollectionAthleteSecondaryMarketRoyaltyPercentage(1, 10)

        // check athlete secondary market royalty percentage
        expect(await (await nftContract.collections(1)).athleteSecondarySalesPercentage).to.equal(10)
    })


    /// PLATFORM UPDATES

    it("checks that PLATFORM MANAGER can update platform primary market address", async () => {
        // check platform primary market address
        expect(await (await nftContract.fantiumPrimarySalesAddress())).to.equal(fantium.address)

        // update platform primary market address
        await nftContract.connect(platformManager).updateFantiumPrimarySaleAddress(other.address)

        // check platform primary market address
        expect(await (await nftContract.fantiumPrimarySalesAddress())).to.equal(other.address)
    })

    it("checks that PLATFORM MANAGER can update platform secondary market address", async () => {
        // check platform secondary market address
        expect(await (await nftContract.fantiumSecondarySalesAddress())).to.equal(fantium.address)

        // update platform secondary market address
        await nftContract.connect(platformManager).updateFantiumSecondarySaleAddress(other.address)

        // check platform secondary market address
        expect(await (await nftContract.fantiumSecondarySalesAddress())).to.equal(other.address)
    })

    it("checks that PLATFORM MANAGER can update platform secondary market royalty PBS", async () => {
        // check platform secondary market royalty percentage
        expect(await (await nftContract.fantiumSecondarySalesBPS())).to.equal(250)

        // update platform secondary market royalty percentage
        await nftContract.connect(platformManager).updateFantiumSecondaryMarketRoyaltyBPS(100)

        // check platform secondary market royalty percentage
        expect(await (await nftContract.fantiumSecondarySalesBPS())).to.equal(100)
    })
})

