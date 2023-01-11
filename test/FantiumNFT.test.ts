import { ethers, upgrades } from 'hardhat'
import { expect } from 'chai'
import { beforeEach } from 'mocha'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { FantiumNFT } from '../typechain-types/contracts/FantiumNFT'
import { Mock20 } from '../typechain-types/contracts/Mock20'

describe("FANtiumNFT V1", () => {

    let nftContract: FantiumNFT
    let erc20Contract: Mock20
    let defaultAdmin: SignerWithAddress
    let platformManager: SignerWithAddress
    let kycManager: SignerWithAddress
    let fantium: SignerWithAddress
    let athlete: SignerWithAddress
    let fan: SignerWithAddress
    let other: SignerWithAddress

    const primarySalePercentage = 9000
    const secondarySalePercentage = 500
    const maxInvocations = 100
    const price = 100
    const earningsSplit = 10
    let timestamp = 0
    let decimals = 18
    let fantiumSecondaryBPS = 250

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

        const FantiumNFT = await ethers.getContractFactory("FantiumNFT")
        nftContract = await upgrades.deployProxy(FantiumNFT, ["FANtium", "FAN", defaultAdmin.address], { initializer: 'initialize' }) as FantiumNFT

        // set Roles
        await nftContract.connect(defaultAdmin).grantRole(await nftContract.PLATFORM_MANAGER_ROLE(), platformManager.address)
        await nftContract.connect(defaultAdmin).grantRole(await nftContract.KYC_MANAGER_ROLE(), kycManager.address)

        // set payment token
        await nftContract.connect(platformManager).updatePaymentToken(erc20Contract.address)

        // get timestamp
        timestamp = (await ethers.provider.getBlock("latest")).timestamp

        // add first collection
        await nftContract.connect(platformManager).addCollection(
            athlete.address,
            primarySalePercentage,
            secondarySalePercentage,
            maxInvocations,
            price,
            earningsSplit,
            timestamp,
            fantium.address,
            fantiumSecondaryBPS
        )

        // set contract base URI
        await nftContract.connect(platformManager).updateBaseURI("https://contract.com/")

        // set erc20 token address
        await nftContract.connect(platformManager).updatePaymentToken(erc20Contract.address)

        // pause the contract
        await nftContract.connect(platformManager).pause()

        // unpause contract
        await nftContract.connect(platformManager).unpause()

        // set decoimals
        decimals = await erc20Contract.decimals()
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

        // contract payment token
        expect(await nftContract.erc20PaymentToken()).to.equal(erc20Contract.address)
    })


    /// CONTRACT PAUSING

    it("checks that PLATFORM MANAGER can pause contract", async () => {
        // pause contract
        await nftContract.connect(platformManager).pause()

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
        await nftContract.connect(platformManager).increaseAllowListAllocation(1, fan.address, 1)
        expect(await nftContract.collectionIdToAllowList(1, fan.address)).to.equal(1)
    })

    it("checks that PLATFORM MANAGER can remove completely from Allowlist", async () => {
        expect(await nftContract.collectionIdToAllowList(1, fan.address)).to.equal(0)
        // add fan address to allowlist with 2 allocations
        await nftContract.connect(platformManager).increaseAllowListAllocation(1, fan.address, 2)
        expect(await nftContract.collectionIdToAllowList(1, fan.address)).to.equal(2)

        // remove fan address from allowlist completely
        await nftContract.connect(platformManager).reduceAllowListAllocation(1, fan.address, 100)
        expect(await nftContract.collectionIdToAllowList(1, fan.address)).to.equal(0)
    })

    it("checks that PLATFORM MANAGER can remove partially from Allowlist", async () => {
        expect(await nftContract.collectionIdToAllowList(1, fan.address)).to.equal(0)
        // add fan address to allowlist with 2 allocations
        await nftContract.connect(platformManager).increaseAllowListAllocation(1, fan.address, 2)
        expect(await nftContract.collectionIdToAllowList(1, fan.address)).to.equal(2)

        // reduce fan address allocation by 1
        await nftContract.connect(platformManager).reduceAllowListAllocation(1, fan.address, 1)
        expect(await nftContract.collectionIdToAllowList(1, fan.address)).to.equal(1)
    })


    /// MINTING

    it("checks that FAN cannot mint if NOT kyced", async () => {
        // check status of fan address
        expect(await nftContract.isAddressKYCed(fan.address)).to.equal(false)

        // ty to mint
        await expect(nftContract.connect(fan).mint(1)).to.be.revertedWith("Address is not KYCed");
    })

    it("checks that FAN cannot mint if kyced & NOT on allowlist & collection is not activated", async () => {
        // add fan address to KYC
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)

        // check if fan can mint
        await expect(nftContract.connect(fan).mint(1)).to.be.revertedWith("Collection is not mintable");
    })

    it("checks that FAN cannot mint if kyced & on allowlist & collection mintable & collection paused & Allowance is too low", async () => {
        // add fan address to KYC
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        // add fan address to allowlist with 1 allocations
        await nftContract.connect(platformManager).increaseAllowListAllocation(1, fan.address, 1)
        // activate collection
        await nftContract.connect(platformManager).toggleCollectionMintable(1)

        // check if fan can mint
        await expect(nftContract.connect(fan).mint(1)).to.be.revertedWith("ERC20 allowance too low");
    })

    it("checks that FAN can mint if kyced & on allowlist & collection minting paused & price is correct", async () => {
        // add fan address to KYC
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        // add fan address to allowlist with 1 allocation
        await nftContract.connect(platformManager).increaseAllowListAllocation(1, fan.address, 1)
        await nftContract.connect(platformManager).toggleCollectionMintable(1)
        // // check if fan can mint
        await erc20Contract.connect(fan).approve(nftContract.address, ethers.utils.parseUnits(price.toString(), await erc20Contract.decimals()))
        await nftContract.connect(fan).mint(1);

        // // check fan balance
        expect(await nftContract.balanceOf(fan.address)).to.equal(1);
    })

    it("checks that FAN cannot mint if kyced & on allowlist & collection minting paused & price is correct & allowlist allocation is used up", async () => {
        // add fan address to KYC
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        // add fan address to allowlist with 1 allocation
        await nftContract.connect(platformManager).increaseAllowListAllocation(1, fan.address, 1)

        // activate 
        await nftContract.connect(platformManager).toggleCollectionMintable(1)

        // // check if fan can mint
        await erc20Contract.connect(fan).approve(nftContract.address, ethers.utils.parseUnits(price.toString(), await erc20Contract.decimals()).mul(2))

        console.log(ethers.utils.parseUnits(price.toString(), await erc20Contract.decimals()))
        await nftContract.connect(fan).mint(1);

        // // check fan balance
        expect(await nftContract.balanceOf(fan.address)).to.equal(1);
        // // check if fan can mint again
        await expect(nftContract.connect(fan).mint(1)).to.be.revertedWith("Collection is paused");
    })

    it("checks that FAN CAN mint if kyced & collection minting is & price is correct", async () => {
        // add fan address to KYC
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        // unpause collection minting
        await nftContract.connect(platformManager).toggleCollectionPaused(1)
        await nftContract.connect(platformManager).toggleCollectionMintable(1)
        // check if fan can mint
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals)
        await nftContract.connect(fan).mint(1);

        // check fan balance
        expect(await nftContract.balanceOf(fan.address)).to.equal(1);
    })

    /// PRIMARY SALE SPLIT

    it("checks that ATHLETE primary sales split is correct", async () => {
        // check athlete balance
        const balanceBefore = await erc20Contract.balanceOf(athlete.address)//await athlete.getBalance()

        console.log("balanceBefore", balanceBefore.toString())

        // approve nft contract to spend Mock20
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals)

        // mint NFT
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        await nftContract.connect(platformManager).toggleCollectionMintable(1)
        await nftContract.connect(platformManager).toggleCollectionPaused(1)
        await nftContract.connect(fan).mint(1);

        // check athlete balance after mint
        const balanceAfter = await erc20Contract.balanceOf(athlete.address)

        console.log("balanceAfter", balanceAfter.toNumber() / 10 ** decimals)

        expect(balanceAfter.sub(balanceBefore)).to.equal(90 * 10 ** decimals)
    })

    it("checks that FANtium primary sales split is correct", async () => {
        // check FANtium balance
        const balanceBefore = await erc20Contract.balanceOf(fantium.address)

        // approve nft contract to spend Mock20
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals)

        // mint NFT
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        await nftContract.connect(platformManager).toggleCollectionMintable(1)
        await nftContract.connect(platformManager).toggleCollectionPaused(1)
        await nftContract.connect(fan).mint(1);

        // check FANtium balance after mint
        const balanceAfter = await erc20Contract.balanceOf(fantium.address)
        expect(balanceAfter.sub(balanceBefore)).to.equal(10 * 10 ** decimals)
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
                10,
                timestamp,
                fantium.address,
                250
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
                10,
                timestamp,
                fantium.address,
                250
            )).to.be.revertedWith('Invalid address')
    })

    /// COLLECTION UPDATES

    it("checks that PLATFORM MANAGER cannot update athlete address with 0x0 address", async () => {
        // try to update collection athlete address
        await expect(nftContract.connect(platformManager).updateCollectionAthleteAddress(1, ethers.constants.AddressZero)).to.be.revertedWith("Invalid address");
    })

    it("checks that PLATFORM MANAGER can toggle collection isMintingPause", async () => {
        // check collection is paused
        expect((await nftContract.collections(1)).isPaused).to.equal(true)

        // toggle collection  paused
        await nftContract.connect(platformManager).toggleCollectionPaused(1)
        // check collection minting is unPaused
        expect((await nftContract.collections(1)).isPaused).to.equal(false)

        // toggle collection is paused
        await nftContract.connect(platformManager).toggleCollectionPaused(1)
        // check collection is paused
        expect((await nftContract.collections(1)).isPaused).to.equal(true)
    })

    it("checks that PLATFORM MANAGER can toggle isActivated", async () => {
        // check collection is paused
        expect((await nftContract.collections(1)).isMintable).to.equal(false)

        // update collection pause status
        await nftContract.connect(platformManager).toggleCollectionMintable(1)

        // check collection is unPaused
        expect((await nftContract.collections(1)).isMintable).to.equal(true)
    })

    it("checks that ATHLETE can toggle their collection isMintingPause", async () => {
        // check collection is paused
        expect((await nftContract.collections(1)).isPaused).to.equal(true)

        // toggle collection  paused
        await nftContract.connect(athlete).toggleCollectionPaused(1)
        // check collection minting is unPaused
        expect((await nftContract.collections(1)).isPaused).to.equal(false)

        // toggle collection is paused
        await nftContract.connect(athlete).toggleCollectionPaused(1)
        // check collection is paused
        expect((await nftContract.collections(1)).isPaused).to.equal(true)
    })

    it("checks that PLATFORM MANAGER can update collection athlete address", async () => {
        // check collection athlete address
        expect((await nftContract.collections(1)).athleteAddress).to.equal(athlete.address)

        // update collection athlete address
        await nftContract.connect(platformManager).updateCollectionAthleteAddress(1, other.address)

        // check collection athlete address
        expect((await nftContract.collections(1)).athleteAddress).to.equal(other.address)
    })

    it("checks that PLATFROM MANAGER can update athlete primary market royalty BPS", async () => {
        // check athlete primary market royalty percentage
        expect((await nftContract.collections(1)).athletePrimarySalesBPS).to.equal(9000)

        // update athlete primary market royalty percentage
        await nftContract.connect(platformManager).updateCollectionAthletePrimaryMarketRoyaltyBPS(1, 5000)

        // check athlete primary market royalty percentage
        expect((await nftContract.collections(1)).athletePrimarySalesBPS).to.equal(5000)
    })

    it("checks that PLATFROM MANAGER can update athlete secondary market royalty BPS", async () => {
        // check athlete secondary market royalty percentage
        expect((await nftContract.collections(1)).athleteSecondarySalesBPS).to.equal(500)

        // update athlete secondary market royalty percentage
        await nftContract.connect(platformManager).updateCollectionAthleteSecondaryMarketRoyaltyBPS(1, 10)

        // check athlete secondary market royalty percentage
        expect((await nftContract.collections(1)).athleteSecondarySalesBPS).to.equal(10)
    })


    /// PLATFORM UPDATE

    it("checks that PLATFORM MANAGER can update platform secondary market address", async () => {
        // check platform secondary market address
        expect((await nftContract.collections(1)).fantiumSalesAddress).to.equal(fantium.address)

        // update platform secondary market address
        await nftContract.connect(platformManager).updateFantiumSalesInformation(1, other.address, 100)

        // check platform secondary market address
        expect((await nftContract.collections(1)).fantiumSalesAddress).to.equal(other.address)

        // check platform secondary market royalty percentage
        expect((await nftContract.collections(1)).fantiumSecondarySalesBPS).to.equal(100)
    })

    it("checks that PLATFROM MANAGER can update collection sales parameters", async () => {
        await nftContract.connect(platformManager).updateCollectionSales(1, 100, 10000, 10)
    })

    it("checks that secondary sales information is correct", async () => {

        // approve nft contract to spend Mock20
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals)

        // mint NFT
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        await nftContract.connect(platformManager).toggleCollectionMintable(1)
        await nftContract.connect(platformManager).toggleCollectionPaused(1)
        await nftContract.connect(fan).mint(1);

        console.log("fantium address: ", fantium.address)
        console.log("athlete address: ", athlete.address)
        console.log(await nftContract.getRoyalties(1000000))
    })

    it("checks that PLATFORM MANAGER can mint even if collection is not launched", async () => {
        // transfer Mock20 to platform manager
        await erc20Contract.connect(fan).transfer(platformManager.address, price * 10 ** decimals)

        // approve nft contract to spend Mock20
        await erc20Contract.connect(platformManager).approve(nftContract.address, price * 10 ** decimals)

        // mint NFT
        await nftContract.connect(kycManager).addAddressToKYC(platformManager.address)
        await nftContract.connect(platformManager).toggleCollectionMintable(1)
        await nftContract.connect(platformManager).toggleCollectionPaused(1)
        await nftContract.connect(platformManager).mint(1);

        // check NFT owner
        expect(await nftContract.ownerOf(1000000)).to.equal(platformManager.address)
    })

})

