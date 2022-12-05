import { ethers, upgrades } from 'hardhat'
import { expect } from 'chai'
import { beforeEach } from 'mocha'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { FantiumNFTV1 } from '../typechain-types/contracts/FantiumNFTV1'

describe("FANtiumNFT", () => {

    let nftContract: FantiumNFTV1
    let defaultAdmin: SignerWithAddress
    let platformManager: SignerWithAddress
    let kycManager: SignerWithAddress
    let fantium: SignerWithAddress
    let athlete: SignerWithAddress
    let fan: SignerWithAddress
    let other: SignerWithAddress

    beforeEach(async () => {
        const [_defaultAdmin, _platformManager, _kycManager, _fantium, _athlete, _fan, _other] = await ethers.getSigners()
        defaultAdmin = _defaultAdmin
        platformManager = _platformManager
        kycManager = _kycManager
        fantium = _fantium
        athlete = _athlete
        fan = _fan
        other = _other

        const FantiumNFTV1 = await ethers.getContractFactory("FantiumNFTV1")
        nftContract = await upgrades.deployProxy(FantiumNFTV1, ["FANtium", "FAN", defaultAdmin.address], { initializer: 'initialize' }) as FantiumNFTV1

        // set Roles
        await nftContract.connect(defaultAdmin).grantRole(await nftContract.PLATFORM_MANAGER_ROLE(), platformManager.address)
        await nftContract.connect(defaultAdmin).grantRole(await nftContract.KYC_MANAGER_ROLE(), kycManager.address)

        // set Fantium address for primary sale
        await nftContract.connect(platformManager).updateFantiumPrimarySaleAddress(fantium.address)
        await nftContract.connect(platformManager).updateFantiumSecondarySaleAddress(fantium.address)
        await nftContract.connect(platformManager).updateFantiumSecondaryMarketRoyaltyBPS(250)

        // set Tiers
        await nftContract.connect(platformManager).updateTiers("bronze", 10, 10000, 10)
        await nftContract.connect(platformManager).updateTiers("silver", 100, 1000, 20)
        await nftContract.connect(platformManager).updateTiers("gold", 1000, 100, 30)

        // add first collection
        await nftContract.connect(platformManager).addCollection(
            "Test Collection",
            "Test Athlete Name",
            "https://test.com/",
            athlete.address,
            90,
            5,
            "silver",
        )

        // set contract base URI
        await nftContract.connect(platformManager).updateBaseURI("https://contract.com/")
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
        await expect(nftContract.connect(fan).mint(1)).to.be.revertedWith("Address is not KYCed");
    })

    it("checks that FAN cannot mint if kyced & NOT on allowlist & collection minting paused", async () => {
        // add fan address to KYC
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)

        // check if fan can mint
        await expect(nftContract.connect(fan).mint(1)).to.be.revertedWith("Minting is paused");
    })

    it("checks that FAN cannot mint if kyced & on allowlist & collection minting paused & price is NOT correct (too low)", async () => {
        // add fan address to KYC
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        // add fan address to allowlist with 1 allocations
        await nftContract.connect(platformManager).addAddressToAllowListWithAllocation(1, fan.address, 1)

        // check if fan can mint
        await expect(nftContract.connect(fan).mint(1, { value: 10 })).to.be.revertedWith("Incorrect amount sent");
    })

    it("checks that FAN can mint if kyced & on allowlist & collection minting paused & price is correct", async () => {
        // add fan address to KYC
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        // add fan address to allowlist with 1 allocation
        await nftContract.connect(platformManager).addAddressToAllowListWithAllocation(1, fan.address, 1)
        // // check if fan can mint
        await nftContract.connect(fan).mint(1, { value: 100000000000000 });

        // // check fan balance
        expect(await nftContract.balanceOf(fan.address)).to.equal(1);
    })

    it("checks that FAN cannot mint if kyced & on allowlist & collection minting paused & price is correct & allowlist allocation is used up", async () => {
        // add fan address to KYC
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        // add fan address to allowlist with 1 allocation
        await nftContract.connect(platformManager).addAddressToAllowListWithAllocation(1, fan.address, 1)
        // // check if fan can mint
        await nftContract.connect(fan).mint(1, { value: 100000000000000 });

        // // check fan balance
        expect(await nftContract.balanceOf(fan.address)).to.equal(1);
        // // check if fan can mint again
        await expect(nftContract.connect(fan).mint(1, { value: 100000000000000 })).to.be.revertedWith("Minting is paused");
    })

    it("checks that FAN CAN mint if kyced & collection minting is & price is correct", async () => {
        // add fan address to KYC
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        // unpause collection minting
        await nftContract.connect(platformManager).toggleCollectionIsPaused(1)
        // check if fan can mint
        await nftContract.connect(fan).mint(1, { value: 100000000000000 });

        // check fan balance
        expect(await nftContract.balanceOf(fan.address)).to.equal(1);
    })

    /// PRIMARY SALE SPLIT

    it("checks that ATHLETE primary sales split is correct", async () => {
        // check athlete balance
        const balanceBefore = await athlete.getBalance()
        // mint NFT
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        await nftContract.connect(platformManager).toggleCollectionIsPaused(1)
        await nftContract.connect(fan).mint(1, { value: 100000000000000 });
        // check athlete balance after mint
        const balanceAfter = await athlete.getBalance()

        expect(balanceAfter.sub(balanceBefore)).to.equal(90)
    })

    it("checks that FANtium primary sales split is correct", async () => {
        // check FANtium balance
        const balanceBefore = await fantium.getBalance()
        // mint NFT
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        await nftContract.connect(platformManager).toggleCollectionIsPaused(1)
        await nftContract.connect(fan).mint(1, { value: 100000000000000 });
        // check FANtium balance after mint
        const balanceAfter = await fantium.getBalance()

        expect(balanceAfter.sub(balanceBefore)).to.equal(10)
    })


    /// ADD COLLECTION

    it("checks that OTHER cannot add collection if NOT PLATFORM MANAGER", async () => {
        await expect(nftContract.connect(other)
            .addCollection(
                "Test Collection",
                "Test",
                "https://test.com/",
                athlete.address,
                90,
                5,
                "silver"
            )).to.be.revertedWith('AccessControl: account 0x976ea74026e726554db657fa54763abd0c3a0aa9 is missing role 0xab538675bf961a344c31ab0f84b867b850736e871cc7bf3055ce65100abe02ea')
    })

    it("checks that PLATFORM MANAGER cannot add collections with invalid tier name", async () => {
        await expect(nftContract.connect(platformManager)
            .addCollection(
                "Test Collection",
                "Test",
                "https://test.com/",
                athlete.address,
                90,
                5,
                "invalidTier"
            )).to.be.revertedWith('Invalid tier')
    })

    it("checks that PLATFORM MANAGER cannot add collections with 0x0 athlete address", async () => {
        await expect(nftContract.connect(platformManager)
            .addCollection(
                "Test Collection",
                "Test",
                "https://test.com/",
                ethers.constants.AddressZero,
                90,
                5,
                "silver")).to.be.revertedWith('Invalid address')
    })

    /// COLLECTION UPDATES

    it("checks that PLATFORM MANAGER can update collection name", async () => {
        // update collection name
        await nftContract.connect(platformManager).updateCollectionName(1, "New Collection Name")

        // check collection name
        expect(await (await nftContract.collections(1)).name).to.equal("New Collection Name")
    })

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

    it("checks that PLATFORM MANAGER cannot update collection tier with invalid tier name", async () => {
        // try to update collection tier
        await expect(nftContract.connect(platformManager).updateCollectionTier(1, "invalidTier")).to.be.revertedWith("Invalid tier");
    })

    it("checks that PLATFORM MANAGER can update collection base URI", async () => {
        // check collection base URI
        expect(await (await nftContract.collections(1)).collectionBaseURI).to.equal("https://test.com/")

        // update collection base URI
        await nftContract.connect(platformManager).updateCollectionBaseURI(1, "https://new.com/")

        // check collection base URI
        expect(await (await nftContract.collections(1)).collectionBaseURI).to.equal("https://new.com/")
    })

    it("checks that PLATFORM MANAGER can update collection athlete name", async () => {
        // check collection athlete name
        expect(await (await nftContract.collections(1)).athleteName).to.equal("Test Athlete Name")

        // update collection athlete name
        await nftContract.connect(platformManager).updateCollectionAthleteName(1, "New Athlete Name")

        // check collection athlete name
        expect(await (await nftContract.collections(1)).athleteName).to.equal("New Athlete Name")
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

    /// TOKEN

    it("checks that if the collection base URI is set, collection base URI takes precedence over contract base URI", async () => {
        // check collection base URI
        expect(await (await nftContract.collections(1)).collectionBaseURI).to.equal("https://test.com/")

        // mint token
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        await nftContract.connect(platformManager).toggleCollectionIsPaused(1)
        await nftContract.connect(fan).mint(1, { value: 100000000000000 });
        const tokenURI = await nftContract.tokenURI(1000001)

        expect(tokenURI).to.equal("https://test.com/1000001")
    })

    it("checks that if collection base URI is not set, token URI takes contract base URI", async () => {
        // check collection base URI
        expect(await (await nftContract.collections(1)).collectionBaseURI).to.equal("https://test.com/")

        // update collection base URI
        await nftContract.connect(platformManager).updateCollectionBaseURI(1, "")

        // check collection base URI
        expect(await (await nftContract.collections(1)).collectionBaseURI).to.equal("")

        // check contract base URI
        expect(await (await nftContract.baseURI())).to.equal("https://contract.com/")

        // mint token
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        await nftContract.connect(platformManager).toggleCollectionIsPaused(1)
        await nftContract.connect(fan).mint(1, { value: 100000000000000 });
        const tokenURI = await nftContract.tokenURI(1000001)

        expect(tokenURI).to.equal("https://contract.com/1000001")
    })
})

