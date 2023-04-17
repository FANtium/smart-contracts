import { ethers, upgrades } from 'hardhat'
import { expect } from 'chai'
import { beforeEach } from 'mocha'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { FantiumNFTV2 } from '../typechain-types/contracts/FantiumNFTV2'
import { FantiumNFTV3 } from '../typechain-types/contracts/FantiumNFTV3'
import { FantiumClaimingV1} from '../typechain-types/contracts/claiming/FantiumClaimingV1'
import {FantiumUserManager} from '../typechain-types/contracts/utils/FantiumUserManager'
import { Mock20 } from '../typechain-types/contracts/mocks/Mock20'
import { mine } from "@nomicfoundation/hardhat-network-helpers";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { start } from 'repl'

describe("FantiumNFTV3", () => {

    let nftContract: FantiumNFTV2
    let nftContractV3: FantiumNFTV3
    let claimContract: FantiumClaimingV1
    let userManager: FantiumUserManager
    let erc20Contract: Mock20
    let defaultAdmin: SignerWithAddress
    let platformManager: SignerWithAddress
    let upgraderRole: SignerWithAddress
    let kycManager: SignerWithAddress
    let fantium: SignerWithAddress
    let athlete: SignerWithAddress
    let fan: SignerWithAddress
    let other: SignerWithAddress
    let forwarder: SignerWithAddress

    const primarySalePercentage = 9000
    const secondarySalePercentage = 500
    const maxInvocations = 11
    const price = 1
    const tournamentEarningsShare1e7 = 100000 // 0.1%
    const tournamentEarnings = 500000000000 // in 500,000 USDC without decimals
    const tournamentTokenShareBPS = 1000 // 10%
    const otherEarningsShare1e7 = 100000 // 0.1%
    const otherEarnings = 500000000000 // in 50,000 USDC without decimals 
    const otherTokenShareBPS = 1000 // 10%
    const totalAmount = tournamentEarnings + otherEarnings
    const nullAddress = "0x0000000000000000000000000000000000000000"
    let timestamp = 1
    let startTime = 1
    let closeTime = 1876044473
    let decimals = 6
    let fantiumSecondaryBPS = 250
    let fantiumFeePBS = 250

    beforeEach(async () => {
        const [_defaultAdmin, _platformManager, _upgraderRole, _kycManager, _fantium, _athlete, _fan, _other, _forwarder] = await ethers.getSigners()
        defaultAdmin = _defaultAdmin
        platformManager = _platformManager
        upgraderRole = _upgraderRole
        kycManager = _kycManager
        fantium = _fantium
        athlete = _athlete
        fan = _fan
        other = _other
        forwarder = _forwarder

        const Mock20 = await ethers.getContractFactory("Mock20")
        erc20Contract = await Mock20.connect(fan).deploy() as Mock20
        await erc20Contract.connect(fan).transfer(defaultAdmin.address, 1000000 * 10 ** decimals)
        await erc20Contract.connect(fan).transfer(athlete.address, 1000000 * 10 ** decimals)
        await erc20Contract.connect(fan).transfer(platformManager.address, 1000000 * 10 ** decimals)
        await erc20Contract.connect(fan).transfer(fantium.address,  1000000 * 10 ** decimals)
        await erc20Contract.connect(fan).transfer(kycManager.address, 1000000 * 10 ** decimals)
        await erc20Contract.connect(fan).transfer(other.address, price * 10 * 10 ** decimals)
        
        /*//////////////////////////////////////////////////////////////
                            SETUP NFT CONTRACT
        //////////////////////////////////////////////////////////////*/
        
        const FantiumNFTV2 = await ethers.getContractFactory("FantiumNFTV2")
        nftContract = await upgrades.deployProxy(FantiumNFTV2, ["FANtium", "FAN", defaultAdmin.address], { initializer: 'initialize' }) as FantiumNFTV2

        // set Roles
        await nftContract.connect(defaultAdmin).grantRole(await nftContract.PLATFORM_MANAGER_ROLE(), platformManager.address)
        await nftContract.connect(defaultAdmin).grantRole(await nftContract.UPGRADER_ROLE(), upgraderRole.address)
        await nftContract.connect(defaultAdmin).grantRole(await nftContract.KYC_MANAGER_ROLE(), kycManager.address)
        // set payment token
        await nftContract.connect(platformManager).updatePaymentToken(erc20Contract.address)
        // get timestamp
        timestamp = (await ethers.provider.getBlock("latest")).timestamp

        // set contract base URI
        await nftContract.connect(platformManager).updateBaseURI("https://contract.com/")
        // set erc20 token address
        await nftContract.connect(platformManager).updatePaymentToken(erc20Contract.address)
        
        // set decimals
        decimals = await erc20Contract.decimals()

        // add first collection 

        for (let i = 0; i < 4; i++) {
            await nftContract.connect(platformManager).addCollection(
                athlete.address,
                primarySalePercentage,
                secondarySalePercentage,
                maxInvocations,
                price,
                timestamp,
                fantium.address,
                fantiumSecondaryBPS,
                tournamentEarningsShare1e7,
            )
        }
        
        // toggle and unpause collection mintable
        await nftContract.connect(platformManager).toggleCollectionMintable(1)
        await nftContract.connect(platformManager).toggleCollectionPaused(1)


        /*//////////////////////////////////////////////////////////////
                        SETUP CLAIMING CONTRACT
        //////////////////////////////////////////////////////////////*/

        const FantiumClaimingV1 = await ethers.getContractFactory("FantiumClaimingV1")
        claimContract = await upgrades.deployProxy(FantiumClaimingV1, [defaultAdmin.address, erc20Contract.address, nftContract.address, forwarder.address], { initializer: 'initialize' }) as FantiumClaimingV1
        // set Role
        await claimContract.connect(defaultAdmin).grantRole(await claimContract.PLATFORM_MANAGER_ROLE(), platformManager.address)
        // pause the contract
        await claimContract.connect(platformManager).pause()
        // unpause contract
        await claimContract.connect(platformManager).unpause()


        /*//////////////////////////////////////////////////////////////
                        SETUP USER MANAGER CONTRACT
        //////////////////////////////////////////////////////////////*/

        const FantiumUserManager = await ethers.getContractFactory("FantiumUserManager")
        userManager = await upgrades.deployProxy(FantiumUserManager, [defaultAdmin.address, nftContract.address, claimContract.address]) as FantiumUserManager
        //set Role and 
        await userManager.connect(defaultAdmin).grantRole(await userManager.PLATFORM_MANAGER_ROLE(), platformManager.address)
        await userManager.connect(defaultAdmin).grantRole(await userManager.PLATFORM_MANAGER_ROLE(), kycManager.address)
        await userManager.connect(platformManager).addAllowedConctract(nftContract.address)
        await userManager.connect(platformManager).addAllowedConctract(claimContract.address)
        await claimContract.connect(platformManager).updateFantiumUserManager(userManager.address)

    })

    ////////////////////////////////////////////

    // UPGRADE CONTRACTS

    it("Check Setup: upgrading contract and minting NFTs on upgraded contract", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3 ) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, claimContract.address, userManager.address, forwarder.address)
        await nftContractV3.connect(platformManager).updateCollectionSales(1,maxInvocations,price,tournamentEarningsShare1e7,otherEarningsShare1e7,fantium.address,fantiumSecondaryBPS)

        // check name   
        expect(await nftContractV3.name()).to.equal("FANtium")

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(fan.address)
        
        // approve erc20
        await erc20Contract.connect(fan).approve(nftContractV3.address, 3 * price * (10 ** decimals))

        // default admin mint a token
        await nftContractV3.connect(fan).mint(1, 3)

        // check balance
        expect(await nftContractV3.balanceOf(fan.address)).to.equal(3)
    })

    it("Check Setup: contract upgrade and state preservation", async () => {

        /// MINT on V1
        // add fan address to KYC
        await userManager.connect(platformManager).addAddressToKYC(fan.address)
        // check if fan can mint
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals)
        await nftContract.connect(kycManager).addAddressToKYC(fan.address)
        await nftContract.connect(fan).batchMint(1,1);

        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3

        /// CHECK STATE
        expect(await nftContractV3.name()).to.equal("FANtium")
        expect(await nftContractV3.balanceOf(fan.address)).to.equal(1)

    })

    /// CONTRACT PARAMETERS

    it("checks contract parameters", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3

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
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        
        // pause contract
        await nftContractV3.connect(platformManager).pause()

        // check contract is paused
        expect(await nftContract.paused()).to.equal(true)
    })

    ////// MINTING

    it("checks that FAN cannot mint if NOT kyced", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)

        // check status of fan address
        expect(await userManager.isAddressKYCed(fan.address)).to.equal(false)

        // ty to mint
        await expect(nftContractV3.connect(fan).mint(1,1)).to.be.revertedWith("Address is not KYCed");
    })

    it("checks that FAN cannot mint if kyced & on allowlist & collection mintable & collection paused & Allowance is too low", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)

        // add fan address to KYC
        await userManager.connect(kycManager).addAddressToKYC(fan.address)
        // add fan address to allowlist with 1 allocations
        await userManager.connect(platformManager).batchAllowlist(1, nftContract.address ,[fan.address], [1])

        // check if fan can mint
        await expect(nftContractV3.connect(fan).mint(1,1)).to.be.revertedWith("ERC20: insufficient allowance");
    })

    it("checks that FAN can mint if kyced & on allowlist & collection minting paused & price is correct", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)
        // add fan address to KYC
        await userManager.connect(kycManager).addAddressToKYC(fan.address)
        await nftContractV3.connect(platformManager).toggleCollectionPaused(1)
        // add fan address to allowlist with 1 allocation
        await userManager.connect(platformManager).batchAllowlist(1, nftContract.address ,[fan.address], [1])
        // check if fan can mint
        await erc20Contract.connect(fan).approve(nftContract.address, ethers.utils.parseUnits(price.toString(), await erc20Contract.decimals()))
        await nftContractV3.connect(fan).mint(1,1);

        // check fan balance
        expect(await nftContract.balanceOf(fan.address)).to.equal(1);
    })

    it("checks that FAN cannot mint if kyced & on allowlist & collection minting paused & price is correct & allowlist allocation is used up", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)
        
        // add fan address to KYC
        await userManager.connect(platformManager).addAddressToKYC(fan.address)
        // add fan address to allowlist with 1 allocation
        await userManager.connect(platformManager).batchAllowlist(1, nftContract.address ,[fan.address], [1])
        await nftContractV3.connect(platformManager).toggleCollectionPaused(1)

        // // check if fan can mint
        await erc20Contract.connect(fan).approve(nftContract.address, ethers.utils.parseUnits(price.toString(), await erc20Contract.decimals()).mul(2))

        await nftContractV3.connect(fan).mint(1,1);

        // // check fan balance
        expect(await nftContractV3.balanceOf(fan.address)).to.equal(1);
        expect(await userManager.hasAllowlist(nftContract.address,1,fan.address)).to.equal(0);

        // // check if fan can mint again
        await expect(nftContractV3.connect(fan).mint(1,1)).to.be.revertedWith("Collection is paused or allowlist allocation insufficient");
    })

    it("checks that FAN CAN mint if kyced & collection minting is & price is correct", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)
        // add fan address to KYC
        await userManager.connect(platformManager).addAddressToKYC(fan.address)
        // check if fan can mint
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals)
        await nftContractV3.connect(fan).mint(1,1);

        // check fan balance
        expect(await nftContractV3.balanceOf(fan.address)).to.equal(1);
    })

    it("minting checks", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)
        // add fan address to KYC
        await userManager.connect(platformManager).addAddressToKYC(fan.address)
        // check if fan can mint
        await erc20Contract.connect(fan).approve(nftContract.address,10 * price * 10 ** decimals)
        await expect(nftContractV3.connect(fan).mint(1,0)).to.be.revertedWith("Amount must be greater than 0 and smaller than 11");
        await expect(nftContractV3.connect(fan).mint(1,11)).to.be.revertedWith("Amount must be greater than 0 and smaller than 11");
        await expect(nftContractV3.connect(fan).mint(10,1)).to.be.revertedWith("Collection does not exist");

        await nftContractV3.connect(platformManager).toggleCollectionMintable(1)
        await expect(nftContractV3.connect(fan).mint(1,1)).to.be.revertedWith("Collection is not mintable");
        await nftContractV3.connect(platformManager).toggleCollectionMintable(1)
        await nftContractV3.connect(platformManager).updateCollectionLaunchTimestamp(1, 1981692934)
        await expect(nftContractV3.connect(fan).mint(1,1)).to.be.revertedWith("Collection not launched");
        await nftContractV3.connect(platformManager).updateCollectionLaunchTimestamp(1, 1)

        await nftContractV3.connect(platformManager).updateCollectionSales(1,6,1,tournamentEarningsShare1e7,otherEarningsShare1e7,fantium.address,fantiumSecondaryBPS)
        await expect(nftContractV3.connect(fan).mint(1,10)).to.be.revertedWith("Max invocations suppassed with amount");

        await nftContractV3.connect(fan).mintTo(fan.address,1,1)
        expect(await nftContractV3.connect(fan).balanceOf(fan.address)).to.equal(1)

    })

    ////// BATCH MINTING

    it("checks that FAN can batchmint 10 NFTs if collection is Mintable and Unpaused", async () => {
        /// DEPLOY V2
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, claimContract.address, userManager.address, forwarder.address)

        /// ADMIN ON V1
        // add fan address to KYC
        await userManager.connect(platformManager).addAddressToKYC(fan.address)
        // check if fan can mint
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals * 10)
        await nftContractV3.connect(fan).batchMintTo([fan.address],[1],[10])
        await expect(nftContractV3.connect(fan).batchMintTo([fan.address],[1,1],[10])).to.be.revertedWith("Arrays must be of equal length")

        /// 
        expect(await nftContractV3.balanceOf(fan.address)).to.equal(10)
    })

    // check that FAN can't mint if collection is not Mintable
    it("checks that FAN can't batchMint if collection is not Mintable", async () => {
        /// DEPLOY V2
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, claimContract.address, userManager.address, forwarder.address)

        /// ADMIN ON V1
        // add fan address to KYC
        await userManager.connect(platformManager).addAddressToKYC(fan.address)
        await nftContract.connect(platformManager).toggleCollectionMintable(1)
        // check if fan can mint
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 * 10 ** decimals)
        await expect(nftContractV3.connect(fan).batchMintTo([fan.address],[1],[10])).to.be.revertedWith("Collection is not mintable")
    })

    // check that FAN can mint if collection is Mintable, Paused and has sufficient allowlist allocation
    it("checks that FAN can mint if collection is Mintable, Paused and has sufficient allowlist allocation", async () => {
        /// DEPLOY V2
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, claimContract.address, userManager.address, forwarder.address)

        /// ADMIN ON V1
        // add fan address to KYC
        await userManager.connect(platformManager).addAddressToKYC(fan.address)
        // set allowlist allocation
        await userManager.connect(platformManager).batchAllowlist(1,nftContract.address ,[fan.address], [10])

        // allocation
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals * 10)

        await nftContractV3.connect(fan).mint(1, 10);
        /// 
        expect(await nftContractV3.balanceOf(fan.address)).to.equal(10)

        // check that tokenIds are minted
        expect(await nftContractV3.tokenURI(1000000)).to.equal("https://contract.com/1000000")

    })


    /// PRIMARY SALE SPLIT

    it("checks that ATHLETE primary sales split is correct", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)
        // check athlete balance
        const balanceBefore = await erc20Contract.balanceOf(athlete.address)//await athlete.getBalance()


        // approve nft contract to spend Mock20
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals)

        // mint NFT
        await userManager.connect(platformManager).addAddressToKYC(fan.address)
        await nftContractV3.connect(fan).mint(1,1);

        // check athlete balance after mint
        const balanceAfter = await erc20Contract.balanceOf(athlete.address)

        expect(balanceAfter.sub(balanceBefore)).to.equal(900000)
    })

    it("checks that FANtium primary sales split is correct", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)

        // check FANtium balance
        const balanceBefore = await erc20Contract.balanceOf(fantium.address)

        // approve nft contract to spend Mock20
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals)

        // mint NFT
        await userManager.connect(platformManager).addAddressToKYC(fan.address)
        await nftContractV3.connect(fan).mint(1,1);

        // check FANtium balance after mint
        const balanceAfter = await erc20Contract.balanceOf(fantium.address)
        expect(balanceAfter.sub(balanceBefore)).to.equal(100000)
    })

    /// ADD COLLECTION

    it("checks that OTHER cannot add collection if NOT PLATFORM MANAGER", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)
        
        await expect(nftContractV3.connect(other)
            .addCollection(
                athlete.address,
                primarySalePercentage,
                secondarySalePercentage,
                maxInvocations,
                price,
                timestamp,
                fantium.address,
                fantiumSecondaryBPS,
                tournamentEarningsShare1e7,
                otherEarningsShare1e7
            )).to.be.reverted
    })

    it("checks that PLATFORM MANAGER cannot add collections with 0x0 athlete address", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)

        await expect(nftContractV3.connect(platformManager)
            .addCollection(
                nullAddress,
                primarySalePercentage,
                secondarySalePercentage,
                maxInvocations,
                price,
                timestamp,
                fantium.address,
                fantiumSecondaryBPS,
                tournamentEarningsShare1e7,
                otherEarningsShare1e7
            )).to.be.revertedWith('FantiumNFTV3: addresses cannot be 0')
    })

    it("checks that PLATFORM MANAGER cannot add faulty collection parameters", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)

        await expect(nftContractV3.connect(platformManager)
            .addCollection(
                athlete.address,
                10001,
                secondarySalePercentage,
                maxInvocations,
                price,
                timestamp,
                fantium.address,
                fantiumSecondaryBPS,
                tournamentEarningsShare1e7,
                otherEarningsShare1e7
            )).to.be.revertedWith('FantiumNFTV3: athletePrimarySalesBPS must be less than 10,000')

        await expect(nftContractV3.connect(platformManager)
            .addCollection(
                athlete.address,
                primarySalePercentage,
                10001,
                maxInvocations,
                price,
                timestamp,
                fantium.address,
                fantiumSecondaryBPS,
                tournamentEarningsShare1e7,
                otherEarningsShare1e7
            )).to.be.revertedWith('FantiumNFTV3: secondary sales BPS must be less than 10,000')


        await expect(nftContractV3.connect(platformManager)
            .addCollection(
                athlete.address,
                primarySalePercentage,
                secondarySalePercentage,
                10001,
                price,
                timestamp,
                fantium.address,
                fantiumSecondaryBPS,
                tournamentEarningsShare1e7,
                otherEarningsShare1e7
            )).to.be.revertedWith('FantiumNFTV3: max invocations must be less than 10,000')

        await expect(nftContractV3.connect(platformManager)
            .addCollection(
                athlete.address,
                primarySalePercentage,
                secondarySalePercentage,
                maxInvocations,
                price,
                timestamp,
                fantium.address,
                fantiumSecondaryBPS,
                1e7+1,
                otherEarningsShare1e7
            )).to.be.revertedWith('FantiumNFTV3: token share must be less than 1e7')
    })

    /// COLLECTION UPDATES

    it("checks that PLATFORM MANAGER cannot update athlete address with 0x0 address", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)
            
        // try to update collection athlete address
        await expect(nftContract.connect(platformManager).updateCollectionAthleteAddress(1, ethers.constants.AddressZero)).to.be.revertedWith("FantiumNFTV3: address cannot be 0");
    })

    it("checks that PLATFORM MANAGER can toggle collection isMintingPause", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)

        // check collection is paused
        expect((await nftContractV3.collections(1)).isPaused).to.equal(false)

        // toggle collection is paused
        await nftContractV3.connect(platformManager).toggleCollectionPaused(1)
        // check collection is paused
        expect((await nftContractV3.collections(1)).isPaused).to.equal(true)
    })

    it("checks that PLATFORM MANAGER can toggle isActivated", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)
        // check collection is paused
        expect((await nftContractV3.collections(1)).isMintable).to.equal(true)

        // update collection pause status
        await nftContractV3.connect(platformManager).toggleCollectionMintable(1)

        // check collection is unPaused
        expect((await nftContractV3.collections(1)).isMintable).to.equal(false)
    })

    it("checks that ATHLETE can toggle their collection isMintingPause", async () => {
        // check collection is paused
        expect((await nftContract.collections(1)).isPaused).to.equal(false)

        // toggle collection  paused
        await nftContract.connect(athlete).toggleCollectionPaused(1)
        // check collection minting is unPaused
        expect((await nftContract.collections(1)).isPaused).to.equal(true)

        // toggle collection is paused
        await nftContract.connect(athlete).toggleCollectionPaused(1)
        // check collection is paused
        expect((await nftContract.collections(1)).isPaused).to.equal(false)
    })

    it("checks that PLATFORM MANAGER can update collection athlete address", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)

        // check collection athlete address
        expect((await nftContractV3.collections(1)).athleteAddress).to.equal(athlete.address)

        // update collection athlete address
        await nftContractV3.connect(platformManager).updateCollectionAthleteAddress(1, other.address)

        // check collection athlete address
        expect((await nftContractV3.collections(1)).athleteAddress).to.equal(other.address)
    })

    it("checks that PLATFROM MANAGER can update athlete primary market royalty BPS", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)

        // check athlete primary market royalty percentage
        expect((await nftContractV3.collections(1)).athletePrimarySalesBPS).to.equal(9000)

        // update athlete primary market royalty percentage
        await nftContractV3.connect(platformManager).updateCollectionAthletePrimaryMarketRoyaltyBPS(1, 5000)

        // check athlete primary market royalty percentage
        expect((await nftContractV3.collections(1)).athletePrimarySalesBPS).to.equal(5000)

        await expect(nftContractV3.connect(platformManager).updateCollectionAthletePrimaryMarketRoyaltyBPS(1, 10001)).to.be.revertedWith("Max of 100%");

    })

    it("checks that PLATFROM MANAGER can update athlete secondary market royalty BPS", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)
        
        // check athlete secondary market royalty percentage
        expect((await nftContractV3.collections(1)).athleteSecondarySalesBPS).to.equal(500)

        // update athlete secondary market royalty percentage
        await nftContractV3.connect(platformManager).updateCollectionAthleteSecondaryMarketRoyaltyBPS(1, 10)

        // check athlete secondary market royalty percentage
        expect((await nftContractV3.collections(1)).athleteSecondarySalesBPS).to.equal(10)

        await expect(nftContractV3.connect(platformManager).updateCollectionAthleteSecondaryMarketRoyaltyBPS(1, 10001)).to.be.revertedWith("FantiumClaimingV1: secondary sales BPS must be less than 10,000");
    })

    it("checks that PLATFROM MANAGER can collection Sales", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)

        await userManager.connect(platformManager).addAddressToKYC(fan.address)
        await erc20Contract.connect(fan).approve(nftContractV3.address, price*1000000000)
        await nftContractV3.connect(fan).mint(1,10)
    
        // update platform secondary market address
        await nftContractV3.connect(platformManager).updateCollectionSales(1, 100,1,1,1,other.address,100)
        expect((await nftContractV3.collections(1)).fantiumSalesAddress).to.equal(other.address)
        expect((await nftContractV3.collections(1)).price).to.equal(1)
        
        await expect(nftContractV3.connect(platformManager).updateCollectionSales(1, 100,0,1,1,other.address,100)).to.be.revertedWith("FantiumNFTV3: all parameters must be greater than 0");
        await expect(nftContractV3.connect(platformManager).updateCollectionSales(1, 100,1,0,0,other.address,100)).to.be.revertedWith("FantiumNFTV3: all parameters must be greater than 0");
        await expect(nftContractV3.connect(platformManager).updateCollectionSales(1, 10001,1,1,1,other.address,100)).to.be.revertedWith("FantiumNFTV3: max invocations must be less than 10,000");
        await expect(nftContractV3.connect(platformManager).updateCollectionSales(1, 100,1,1,1,other.address,10001)).to.be.revertedWith("FantiumNFTV3: secondary sales BPS must be less than 10,000");
        await expect(nftContractV3.connect(platformManager).updateCollectionSales(1, 100,1,1,1,nullAddress,100)).to.be.revertedWith("FantiumNFTV3: address cannot be 0");
        await expect(nftContractV3.connect(platformManager).updateCollectionSales(1, 9,1,1,1,other.address,100)).to.be.revertedWith("FantiumNFTV3: max invocations must be greater than current invocations");

    })

    it("checks that PLATFROM MANAGER can update launch timestmap", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)

    
        // update platform secondary market address
        await nftContractV3.connect(platformManager).updateCollectionLaunchTimestamp(1, closeTime)
        expect((await nftContractV3.collections(1)).launchTimestamp).to.equal(closeTime)

    })

    it("checks that PLATFROM MANAGER can update baseURI", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)

    
        // update platform secondary market address
        await nftContractV3.connect(platformManager).updateBaseURI("https://fantium.io/")
        expect((await nftContractV3.baseURI())).to.equal("https://fantium.io/")

    })


    /// PLATFORM UPDATE

    it("checks that PLATFORM MANAGER can update platform secondary market address", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)
        
        // check platform secondary market address
        expect((await nftContractV3.collections(1)).fantiumSalesAddress).to.equal(fantium.address)

        // update platform secondary market address
        await nftContractV3.connect(platformManager).updateCollectionSales(1, 100,1,1,1,other.address,100)

        // check platform secondary market address
        expect((await nftContractV3.collections(1)).fantiumSalesAddress).to.equal(other.address)

        // check platform secondary market royalty percentage
        expect((await nftContractV3.collections(1)).fantiumSecondarySalesBPS).to.equal(100)
    })

    it("checks that PLATFORM MANAGER can mint even if collection is not launched", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)
        // transfer Mock20 to platform manager
        await erc20Contract.connect(fan).transfer(platformManager.address, price * 10 ** decimals)

        // approve nft contract to spend Mock20
        await erc20Contract.connect(platformManager).approve(nftContractV3.address, price * 10 ** decimals)

        // mint NFT
        await userManager.connect(platformManager).addAddressToKYC(platformManager.address)
        await nftContractV3.connect(platformManager).mint(1,1);

        // check NFT owner
        expect(await nftContractV3.ownerOf(1000000)).to.equal(platformManager.address)
    })

    ////// BATCH ALLOWLISTING

    it("checks that PM can batch allowlist 1000 addresses with allocations", async () => {
        /// DEPLOY V2
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, claimContract.address, userManager.address, forwarder.address)

        /// ADMIN ON V1
        // add fan address to KYC
        await userManager.connect(platformManager).addAddressToKYC(fan.address)
        // unpause collection minting


        // create 50 addresses and allocations
        const addresses = []
        const allocations = []
        for (let i = 0; i < 50; i++) {
            addresses.push(await ethers.Wallet.createRandom().address)
            allocations.push(5)
        }

        /// ADMIN
        // batch allowlist
        await userManager.connect(platformManager).batchAllowlist(1,nftContract.address ,addresses, allocations)

        // check if allowlist is correct
        for (let i = 0; i < 50; i++) {
            expect(await userManager.hasAllowlist(nftContract.address,1, addresses[i])).to.equal(5)
        }
    })

    // TOKEN UPGRADING 

    // check that a token can't be upgraded
    it("check token upgrade can't be triggered by unauthorized", async () => {
        /// DEPLOY V2
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)

        /// ADMIN ON V1
        // add fan address to KYC
        await userManager.connect(platformManager).addAddressToKYC(fan.address)
        // set allowlist allocation
        await userManager.connect(platformManager).batchAllowlist(1,nftContract.address ,[fan.address], [10])

        // upgrade token that doesnt exist
        await expect(nftContractV3.connect(platformManager).upgradeTokenVersion(1000000)).to.revertedWith("Invalid tokenId")

        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals * 10)
        await nftContractV3.connect(fan).mint(1, 10);

        // upgrade token without setting claim contract
        await expect(nftContractV3.connect(platformManager).upgradeTokenVersion(1000000)).to.revertedWith("Only claim contract can call this function")

    })

    // // VIEW FUNCTIONS

    it("checks getter function", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)

        expect( await nftContractV3.connect(platformManager).getCollectionAthleteAddress(1)).to.equal(athlete.address)
        expect(await nftContractV3.connect(platformManager).getEarningsShares1e7(1))
        expect(await nftContractV3.connect(platformManager).getCollectionExists(1)).to.equal(true)
        expect(await nftContractV3.connect(platformManager).getMintedTokensOfCollection(1)).to.equal(0)
    })

    // // OS FILTER

    it("using OS filte functions and seeing normal functionality", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)

        // add fan address to KYC
        await userManager.connect(platformManager).addAddressToKYC(fan.address)

        // allocation
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals * 10)
        await nftContractV3.connect(fan).mint(1, 3);
        
        /// approvals
        await nftContractV3.connect(fan).approve(fantium.address, 1000001)
        expect(await nftContractV3.getApproved(1000001)).to.be.equal(fantium.address)
        await nftContractV3.connect(fan).setApprovalForAll(fantium.address, true)
        expect(await nftContractV3.isApprovedForAll(fan.address,fantium.address)).to.be.equal(true)
        expect(await nftContractV3.isApprovedForAll(fan.address,claimContract.address)).to.be.equal(false)

        //transfers
        expect(await nftContractV3.connect(fan).balanceOf(fan.address)).to.equal(3)
        await nftContractV3.connect(fantium).transferFrom(fan.address,fantium.address, 1000001)
        expect(await nftContractV3.connect(fan).balanceOf(fan.address)).to.equal(2)

    })


    // TRUSTED FORWARDER 
    it("check trusted forwarder", async () => {
        /// DEPLOY V3
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(upgraderRole).updatePlatformAddressesConfigs(erc20Contract.address, erc20Contract.address, userManager.address, forwarder.address)

        expect(await nftContractV3.connect(platformManager).isTrustedForwarder(forwarder.address)).to.equal(true)
        expect(await nftContractV3.connect(platformManager).isTrustedForwarder(fan.address)).to.equal(false)


    })


})


