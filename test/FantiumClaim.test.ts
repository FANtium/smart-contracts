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

describe("FantiumClaim", () => {

    let nftContract: FantiumNFTV2
    let nftContractV3: FantiumNFTV3
    let claimContract: FantiumClaimingV1
    let userManager: FantiumUserManager
    let erc20Contract: Mock20
    let defaultAdmin: SignerWithAddress
    let platformManager: SignerWithAddress
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
        const [_defaultAdmin, _platformManager, _kycManager, _fantium, _athlete, _fan, _other, _forwarder] = await ethers.getSigners()
        defaultAdmin = _defaultAdmin
        platformManager = _platformManager
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
        await nftContract.connect(defaultAdmin).grantRole(await nftContract.UPGRADER_ROLE(), platformManager.address)
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

        for (let i = 0; i < 7; i++) {
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
        await nftContract.connect(platformManager).toggleCollectionMintable(2)
        await nftContract.connect(platformManager).toggleCollectionPaused(2)
        await nftContract.connect(platformManager).toggleCollectionMintable(4)
        await nftContract.connect(platformManager).toggleCollectionPaused(4)


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

        /*//////////////////////////////////////////////////////////////
                        UPGRADE NFT CONTRACT
        //////////////////////////////////////////////////////////////*/

        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(platformManager).updatePlatformAddressesConfigs(erc20Contract.address, claimContract.address, userManager.address, forwarder.address)
        await nftContractV3.connect(platformManager).updateCollectionSales(1,maxInvocations,price,tournamentEarningsShare1e7,otherEarningsShare1e7,fantium.address,fantiumSecondaryBPS)
        await nftContractV3.connect(platformManager).updateCollectionSales(2,maxInvocations,price,tournamentEarningsShare1e7,otherEarningsShare1e7,fantium.address,fantiumSecondaryBPS)

        await erc20Contract.connect(fan).approve(nftContract.address, 1 * price * (10 ** decimals))
        await userManager.connect(kycManager).addAddressToKYC(fan.address)
        await nftContractV3.connect(fan).mint(1, 1)

        /*//////////////////////////////////////////////////////////////
                        SETUP DISTRIBUTION EVENTS
        //////////////////////////////////////////////////////////////*/

        await claimContract.connect(platformManager).setupDistributionEvent(
            athlete.address,
            tournamentEarnings,
            otherEarnings,
            startTime,
            closeTime,
            [1,2,3],
            fantium.address,
            fantiumFeePBS
        )

    })

    //////// CHECK DISTRIBUTION EVENT SETUP

    it("Check Setup: check distributionEvent creation", async () => {

        // check distributionEvent creation is correct
        expect((await claimContract.distributionEvents(1)).totalTournamentEarnings).to.equal(tournamentEarnings)
        expect((await claimContract.distributionEvents(1)).startTime).to.equal(startTime)
        expect((await claimContract.distributionEvents(1)).closeTime).to.equal(closeTime)
        expect((await claimContract.distributionEvents(1)).closed).to.equal(false)
        expect((await claimContract.distributionEvents(1)).distributionEventId).to.equal(1)
        expect((await claimContract.getDistributionEvent(1)).collectionIds[0]).to.equal(1)
        expect((await claimContract.getDistributionEvent(1)).collectionIds[1]).to.equal(2)
        expect((await claimContract.getDistributionEvent(1)).collectionIds[2]).to.equal(3)

        //check that snapshot is correct and calculated correctly payin amount
        expect((await claimContract.distributionEvents(1)).amountPaidIn).to.equal(0)
        expect((await claimContract.distributionEvents(1)).tournamentDistributionAmount).to.equal(tournamentEarnings * 1 * tournamentEarningsShare1e7 / 1e7)
        expect((await claimContract.distributionEvents(1)).otherDistributionAmount).to.equal(otherEarnings * 1 * otherEarningsShare1e7 / 1e7)

        // check collectioninfo is correct
        expect(((await claimContract.distributionEventToCollectionInfo(1,1)).mintedTokens)).to.equal(1)
        expect(((await claimContract.distributionEventToCollectionInfo(1,2)).mintedTokens)).to.equal(0)
        expect(((await claimContract.distributionEventToCollectionInfo(1,3)).mintedTokens)).to.equal(0)
        await expect(((await claimContract.distributionEventToCollectionInfo(1,4)).mintedTokens)).to.equal(0)

        // check claim per NFT is correct
        expect((await claimContract.distributionEventToCollectionInfo(1,1)).tokenTournamentClaim).to.equal(tournamentEarnings * tournamentEarningsShare1e7 / 1e7)
        expect((await claimContract.distributionEventToCollectionInfo(1,1)).tokenOtherClaim).to.equal(otherEarnings * otherEarningsShare1e7 / 1e7)
        expect((await claimContract.distributionEventToCollectionInfo(1,1)).tokenOtherClaim).to.equal(otherEarnings * otherEarningsShare1e7 / 1e7)
        expect((await claimContract.distributionEventToCollectionInfo(1,4)).tokenOtherClaim).to.equal(0)

    })
        
    // check all require statements for distribtionEvents
    it("Check Setup: check requirements for distribtionEvents", async () => {

        // check that others can't create events
        await expect(claimContract.connect(athlete).setupDistributionEvent(
            athlete.address,
            tournamentEarnings,
            otherEarnings,
            startTime,
            closeTime,
            [1,2,3],
            fantium.address,
            fantiumFeePBS
        )).to.be.revertedWith("AccessControl: account 0x15d34aaf54267db7d7c367839aaf71a00a2c6a65 is missing role 0xab538675bf961a344c31ab0f84b867b850736e871cc7bf3055ce65100abe02ea")

        await claimContract.connect(platformManager).updateFantiumNFTContract(nftContract.address)

        await expect(claimContract.connect(platformManager).setupDistributionEvent(
            athlete.address,
            tournamentEarnings,
            otherEarnings,
            0,
            0,
            [1,2,3],
            fantium.address,
            fantiumFeePBS
        )).to.be.revertedWith("FantiumClaimingV1: times must be greater than 0 and close time must be greater than start time and in the future")

        await expect(claimContract.connect(platformManager).setupDistributionEvent(
            athlete.address,
            tournamentEarnings,
            otherEarnings,
            1,
            50,
            [1,2,3],
            fantium.address,
            fantiumFeePBS
        )).to.be.revertedWith("FantiumClaimingV1: times must be greater than 0 and close time must be greater than start time and in the future")

        // test empty collection length
        await expect(claimContract.connect(platformManager).setupDistributionEvent(
            athlete.address,
            tournamentEarnings,
            otherEarnings,
            startTime,
            closeTime,
            [],
            fantium.address,
            fantiumFeePBS
        )).to.be.revertedWith("FantiumClaimingV1: collectionIds must be greater than 0")

        // test fantium fee above 10_000
        await expect(claimContract.connect(platformManager).setupDistributionEvent(
            athlete.address,
            tournamentEarnings,
            otherEarnings,
            startTime,
            closeTime,
            [1,2,3],
            fantium.address,
            110000
        )).to.be.revertedWith("FantiumClaimingV1: fantium fee must be less than 10000")

        // addresses cant be 0
        await expect(claimContract.connect(platformManager).setupDistributionEvent(
            athlete.address,
            tournamentEarnings,
            otherEarnings,
            startTime,
            closeTime,
            [1,2,3],
            nullAddress,
            fantiumFeePBS
        )).to.be.revertedWith("FantiumClaimingV1: addresses cannot be 0")

        // addresses cant be 0
        await expect(claimContract.connect(platformManager).setupDistributionEvent(
            nullAddress,
            tournamentEarnings,
            otherEarnings,
            startTime,
            closeTime,
            [1,2,3],
            fantium.address,
            fantiumFeePBS
        )).to.be.revertedWith("FantiumClaimingV1: addresses cannot be 0")

        // less than a billion
        await expect(claimContract.connect(platformManager).setupDistributionEvent(
            athlete.address,
            1000000000000005,
            otherEarnings,
            startTime,
            closeTime,
            [1,2,3],
            fantium.address,
            fantiumFeePBS
        )).to.be.revertedWith("FantiumClaimingV1: amount must be less than a billion and greater than 0")

        // check that collection that don't exist can't be added
        await expect(claimContract.connect(platformManager).setupDistributionEvent(
            athlete.address,
            tournamentEarnings,
            otherEarnings,
            startTime,
            closeTime,
            [10,11,12],
            fantium.address,
            fantiumFeePBS
        )).to.be.revertedWith("FantiumClaimingV1: collection does not exist")

    })

    //////// CHECK SNAPSHOT MECHANIC

    it("Check Snapshot: check snapshot mechanic", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await erc20Contract.connect(fan).approve(nftContract.address, 1 * price * (10 ** decimals))
        await nftContractV3.connect(fan).mint(1,1)
        
        // not allowed user tries to take snapshot
        await expect(claimContract.connect(athlete).takeClaimingSnapshot(1)).to.be.revertedWith("AccessControl: account 0x15d34aaf54267db7d7c367839aaf71a00a2c6a65 is missing role 0xab538675bf961a344c31ab0f84b867b850736e871cc7bf3055ce65100abe02ea")
        await expect(claimContract.connect(platformManager).takeClaimingSnapshot(5)).to.be.revertedWith("Invalid distribution event")
        await claimContract.connect(platformManager).takeClaimingSnapshot(1)

        expect((await claimContract.distributionEventToCollectionInfo(1,1)).mintedTokens).to.equal(2)
        expect((await claimContract.getDistributionEvent(1)).tournamentDistributionAmount).to.equal(2*tournamentEarnings * tournamentEarningsShare1e7 / 1e7)
        expect((await claimContract.getDistributionEvent(1)).otherDistributionAmount).to.equal(2*otherEarnings * otherEarningsShare1e7 / 1e7)
    })

    //////// CHECK TOP UP MECHANIC
    
    it("Check Payin: check payin mechanic", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await erc20Contract.connect(fan).approve(nftContract.address, 3 * price * (10 ** decimals))
        
        await nftContractV3.connect(fan).mint(1,1)
        
        await claimContract.connect(platformManager).takeClaimingSnapshot(1)

        // try to add distribution amount as external user
        await erc20Contract.connect(fan).approve(claimContract.address, totalAmount)
        await expect(claimContract.connect(fan).addDistributionAmount(1)).to.be.revertedWith("only athlete")
        
        // try distributionEvent that doesn't exist
        await expect(claimContract.connect(platformManager).addDistributionAmount(10)).to.be.revertedWith("FantiumClaimingV1: distributionEventId does not exist")

        // add distribution amount
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1)

        expect((await claimContract.getDistributionEvent(1)).amountPaidIn).to.equal((2*tournamentEarnings * tournamentEarningsShare1e7 / 1e7) + (2*otherEarnings * otherEarningsShare1e7 / 1e7))
        expect((await erc20Contract.balanceOf(claimContract.address))).to.equal((2*tournamentEarnings * tournamentEarningsShare1e7 / 1e7) + (2*otherEarnings * otherEarningsShare1e7 / 1e7))

        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await expect(claimContract.connect(athlete).addDistributionAmount(1)).to.be.revertedWith("FantiumClaimingV1: amount already paid in")
    })
    
    it("Check Payin: check require statements for payin for closed distributionEvents", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await erc20Contract.connect(fan).approve(nftContract.address, 3 * price * (10 ** decimals))
        
        await nftContractV3.connect(fan).mint(1,1)
        
        await claimContract.connect(platformManager).takeClaimingSnapshot(1)

        // add distribution amount
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1)

        
        await claimContract.connect(platformManager).closeDistribution(1)

        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await expect(claimContract.connect(athlete).addDistributionAmount(1)).to.be.revertedWith("FantiumClaimingV1: distribution event not open")

        expect((await claimContract.getDistributionEvent(1)).amountPaidIn).to.equal((2*tournamentEarnings * tournamentEarningsShare1e7 / 1e7) + (2*otherEarnings * otherEarningsShare1e7 / 1e7))
        expect(await erc20Contract.balanceOf(claimContract.address)).to.equal(0)
    })

    ////// CLOSE DISTRIBUTION EVENT MECHANIC

    it("Check Closing: closing a distributionEvent and checking require statements", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        
        // try closing empty distribution event
        await expect(claimContract.connect(platformManager).closeDistribution(1)).to.be.revertedWith("FantiumClaimingV1: Amount to pay is 0")
        
        await erc20Contract.connect(fan).approve(nftContract.address, 3 * price * (10 ** decimals))
        await nftContractV3.connect(fan).mint(1,1)
        
        await claimContract.connect(platformManager).takeClaimingSnapshot(1)
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1)

        expect(await erc20Contract.balanceOf(claimContract.address)).to.equal((2*tournamentEarnings * tournamentEarningsShare1e7 / 1e7) + (2*otherEarnings * otherEarningsShare1e7 / 1e7))
        await claimContract.connect(platformManager).closeDistribution(1)
        // try closing already closed distribution event
        await expect(claimContract.connect(platformManager).closeDistribution(1)).to.be.revertedWith("FantiumClaimingV1: distribution already closed")
        await expect(claimContract.connect(platformManager).closeDistribution(5)).to.be.revertedWith("Invalid distribution event")

        expect((await claimContract.getDistributionEvent(1)).amountPaidIn).to.equal((2*tournamentEarnings * tournamentEarningsShare1e7 / 1e7) + (2*otherEarnings * otherEarningsShare1e7 / 1e7))
        expect(await erc20Contract.balanceOf(claimContract.address)).to.equal(0)
        
    })

    //////// CHECK UPDATE FUNCTIONS

    it("Check Update: total earnings update", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        
        //update distributionEvent
       await expect(claimContract.connect(platformManager).updateDistribtionTotalEarningsAmounts(1, 0, 0)).to.be.revertedWith("FantiumClaimingV1: total amount must be greater than 0")
       await expect(claimContract.connect(platformManager).updateDistribtionTotalEarningsAmounts(5, 1, 1)).to.be.revertedWith("Invalid distribution event")
       
       await claimContract.connect(platformManager).takeClaimingSnapshot(1)
       await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
       await claimContract.connect(athlete).addDistributionAmount(1)
       
       expect(await erc20Contract.balanceOf(claimContract.address)).to.equal((tournamentEarnings * tournamentEarningsShare1e7 / 1e7) + (otherEarnings * otherEarningsShare1e7 / 1e7))

        // check with smaller amount and expect revert 
       await expect(claimContract.connect(platformManager).updateDistribtionTotalEarningsAmounts(1, tournamentEarnings / 2, otherEarnings /2)).to.be.revertedWith("FantiumClaimingV1: total payout amount must be greater than amount already paid in")
       
       // update with same amount and expect revert  
       await expect(claimContract.connect(platformManager).updateDistribtionTotalEarningsAmounts(1, tournamentEarnings, otherEarnings)).to.be.revertedWith("FantiumClaimingV1: amount already paid in")

       // check new balance 
       await claimContract.connect(platformManager).updateDistribtionTotalEarningsAmounts(1, 2*tournamentEarnings, 2*otherEarnings)
       expect(await erc20Contract.balanceOf(claimContract.address)).to.equal((2*tournamentEarnings * tournamentEarningsShare1e7 / 1e7) + (2*otherEarnings * otherEarningsShare1e7 / 1e7))
       
       // check with too large of an amount and expect revert 
       await expect(claimContract.connect(platformManager).updateDistribtionTotalEarningsAmounts(1, 10000*tournamentEarnings, 10000*otherEarnings)).to.be.revertedWith("ERC20: insufficient allowance")
        
    })

    it("Check Update: update collectionId in distributionEvent when already paid in ", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        
        //update distributionEvent
       await expect(claimContract.connect(platformManager).updateDistributionEventCollectionIds(1, [10,11,12])).to.be.revertedWith("FantiumClaimingV1: collection does not exist")
       
       await claimContract.connect(platformManager).takeClaimingSnapshot(1)
       await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
       await claimContract.connect(athlete).addDistributionAmount(1)
       
       await expect(claimContract.connect(platformManager).updateDistributionEventCollectionIds(1, [1,2,3])).to.be.revertedWith("FantiumClaimingV1: amount already paid in")
       await expect(claimContract.connect(platformManager).updateDistributionEventCollectionIds(1, [4,5,6])).to.be.revertedWith("FantiumClaimingV1: total payout amount must be greater than amount already paid in")

    })

    it("Check Update: update collectionId in distributionEvents successfully", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        
        await erc20Contract.connect(fan).approve(nftContract.address, 3 * price * (10 ** decimals))
        await nftContractV3.connect(fan).mint(4,1)

        //update distributionEvent
        await claimContract.connect(platformManager).updateDistributionEventCollectionIds(1, [4,5,6])

        await nftContractV3.connect(fan).mint(1,1)
        await claimContract.connect(platformManager).updateDistributionEventCollectionIds(1, [1,2,3])
    
        
    
    })

    it("Check Update: distributionEvent Addresses", async () => {
        
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        
        expect((await claimContract.distributionEvents(1)).athleteAddress).to.equal(athlete.address)
        expect((await claimContract.distributionEvents(1)).fantiumFeeAddress).to.equal(fantium.address)
        await claimContract.connect(platformManager).updateDistributionEventAddresses(1, fan.address, other.address)
        expect((await claimContract.distributionEvents(1)).athleteAddress).to.equal(fan.address)
        expect((await claimContract.distributionEvents(1)).fantiumFeeAddress).to.equal(other.address)

        await expect(claimContract.connect(platformManager).updateDistributionEventAddresses(1, nullAddress, nullAddress)).to.be.revertedWith("FantiumClaimingV1: athlete address cannot be 0")
    
    })

    it("Check Update: distributionEvent timestamp", async () => {
        
        expect((await claimContract.distributionEvents(1)).startTime).to.equal(startTime)
        expect((await claimContract.distributionEvents(1)).closeTime).to.equal(closeTime)
        await claimContract.connect(platformManager).updateDistributionEventTimeStamps(1, startTime+1, closeTime+1)
        expect((await claimContract.distributionEvents(1)).startTime).to.equal(startTime+1)
        expect((await claimContract.distributionEvents(1)).closeTime).to.equal(closeTime+1)

        await expect(claimContract.connect(platformManager).updateDistributionEventTimeStamps(1, 0, closeTime+1)).to.be.revertedWith("FantiumClaimingV1: times must be greater than 0 and close time must be greater than start time and in the future")
        await expect(claimContract.connect(platformManager).updateDistributionEventTimeStamps(1, startTime,0)).to.be.revertedWith("FantiumClaimingV1: times must be greater than 0 and close time must be greater than start time and in the future")
        await expect(claimContract.connect(platformManager).updateDistributionEventTimeStamps(1, startTime,startTime)).to.be.revertedWith("FantiumClaimingV1: times must be greater than 0 and close time must be greater than start time and in the future")
        await expect(claimContract.connect(platformManager).updateDistributionEventTimeStamps(1, startTime,startTime+5)).to.be.revertedWith("FantiumClaimingV1: times must be greater than 0 and close time must be greater than start time and in the future")
    })

    it("Check Update: distributionEvent Fee", async () => {
        
        expect((await claimContract.distributionEvents(1)).fantiumFeeBPS).to.equal(fantiumFeePBS)
        await claimContract.connect(platformManager).updateDistributionEventFee(1, fantiumFeePBS+1)
        expect((await claimContract.distributionEvents(1)).fantiumFeeBPS).to.equal(fantiumFeePBS+1)

        await expect(claimContract.connect(platformManager).updateDistributionEventFee(1, 10001)).to.be.revertedWith("FantiumClaimingV1: fee must be between 0 and 10000")
    })

    //////// CLAIMING 

    it("Check single claiming: claim, receive amount and check calculation", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(other.address)
        
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV3.address, price * (10 ** decimals))
        await nftContractV3.connect(other).mint(1, 1)

        // athlete adds amount to distribution event 
        await claimContract.connect(platformManager).takeClaimingSnapshot(1)
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1)

        // claim without being IDENT 
        await expect(claimContract.connect(other).claim(1000001, 1)).to.be.revertedWith('FantiumClaimingV1: Only ID verified')

        //add fan to IDENT
        await userManager.connect(platformManager).addAddressToIDENT(other.address)
        await userManager.connect(platformManager).addAddressToIDENT(fan.address)

        // claim with being IDENT
        await claimContract.connect(other).claim(1000001, 1)
        await claimContract.connect(fan).claim(1000000, 1)

        // tournament amount * tokenshare (1000/1e7) / tournamentShareBPS (1000/10000) )
        expect((await(claimContract.getDistributionEvent(1))).claimedAmount).to.equal((2*tournamentEarnings * tournamentEarningsShare1e7 / 1e7) + (2*otherEarnings * otherEarningsShare1e7 / 1e7))
        
        const total_claim = (tournamentEarnings * tournamentEarningsShare1e7 / 1e7) + (otherEarnings * otherEarningsShare1e7 / 1e7)
        const fanClaim = total_claim * ((10000-fantiumFeePBS)/10000)
        const fantiumFee = total_claim * (fantiumFeePBS/10000)
        const fantiumBalance = 2 * fantiumFee + (1000000 * 10 ** decimals) + (2 * price * (10 ** decimals) / 10)

        expect(await(erc20Contract.balanceOf(other.address))).to.equal((fanClaim) + (price * 9 * (10 ** decimals)))
        expect(await(erc20Contract.balanceOf(fantium.address))).to.equal(fantiumBalance)

        expect(await(erc20Contract.balanceOf(claimContract.address))).to.equal(0)

    })

    it("Check batch claiming: claim, receive amount and check calculation", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(other.address)
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV3.address, 10 * price * (10 ** decimals))
        await nftContractV3.connect(other).mint(1, 10)

        // claim with being IDENT
        await claimContract.connect(platformManager).takeClaimingSnapshot(1)
        // athlete adds amount to distribution event 
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1)

        // claim without being IDENT
        await expect(claimContract.connect(other).claim(1000001, 1)).to.be.revertedWith('FantiumClaimingV1: Only ID verified')
        //add fan to IDENT
        await userManager.connect(kycManager).addAddressToIDENT(other.address)
        await userManager.connect(kycManager).addAddressToIDENT(fan.address)
        await claimContract.connect(fan).claim(1000000, 1)
        await claimContract.connect(other).batchClaim([1000001,1000002,1000003,1000004,1000005,1000006,1000007,1000008,1000009,1000010], [1,1,1,1,1,1,1,1,1,1])

        const totalClaim = 11 * ((tournamentEarnings * tournamentEarningsShare1e7 / 1e7) + (otherEarnings * otherEarningsShare1e7 / 1e7))
        const fanClaim = 10/11 * totalClaim * ((10000-fantiumFeePBS)/10000)
        const fantiumFee = totalClaim * (fantiumFeePBS/10000)
        const fantiumBalance = fantiumFee + (1000000 * 10 ** decimals) + (11 * price * (10 ** decimals) / 10)
        
        expect((await(claimContract.getDistributionEvent(1))).claimedAmount).to.equal(totalClaim)
        expect((await(claimContract.getDistributionEvent(1))).amountPaidIn).to.equal(totalClaim)
        expect((await(claimContract.getDistributionEvent(1))).tournamentDistributionAmount).to.equal(11 * tournamentEarnings * tournamentEarningsShare1e7 / 1e7)
        expect((await(claimContract.getDistributionEvent(1))).otherDistributionAmount).to.equal(11 * otherEarnings * otherEarningsShare1e7 / 1e7)
        
        expect(await(erc20Contract.balanceOf(other.address))).to.equal(fanClaim)
        expect(await(erc20Contract.balanceOf(fantium.address))).to.equal(fantiumBalance)

        expect(await(erc20Contract.balanceOf(claimContract.address))).to.equal(0)

    })

    it("Check Error: try to claim without token and fail", async () => {
        //upgrade and setup
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(other.address)
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV3.address, 10 * price * (10 ** decimals))
        await nftContractV3.connect(other).mint(1, 1)

        //// try with invalid token
        await expect(claimContract.connect(fan).claim(1000000, 1)).to.be.revertedWith('FantiumClaimingV1: total distribution amount has not been paid in')

        // add distribution amount
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1)
        await expect(claimContract.connect(fan).claim(1000001, 1)).to.be.revertedWith('FantiumClaimingV1: Only token owner')

        await expect(claimContract.connect(fan).claim(1000000, 1)).to.be.revertedWith('FantiumClaimingV1: Only ID verified')
        await userManager.connect(platformManager).addAddressToIDENT(fan.address)

        await claimContract.connect(platformManager).updateDistributionEventTimeStamps(1,1713306966,1713306969)
        
        await expect(claimContract.connect(fan).claim(1000000, 1)).to.be.revertedWith('FantiumClaimingV1: distribution time has not started or has ended')

        await claimContract.connect(platformManager).updateDistributionEventTimeStamps(1,1,1713306969)

        await claimContract.connect(fan).claim(1000000, 1)
    })
    

    //////// BATCH CLAIMING

    it("Check batch claiming: update of tokenVersion and tokenID", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(other.address)
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV3.address, 10 * price * (10 ** decimals))
        await nftContractV3.connect(other).mint(1, 10)

        // claim with being IDENT
        await claimContract.connect(platformManager).takeClaimingSnapshot(1)
        // athlete adds amount to distribution event 
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1)

        // claim without being IDENT
        await expect(claimContract.connect(other).claim(1000001, 1)).to.be.revertedWith('FantiumClaimingV1: Only ID verified')
        //add fan to IDENT
        await userManager.connect(kycManager).addAddressToIDENT(other.address)
        
        // claim batch
        await claimContract.connect(other).batchClaim([1000001,1000002,1000003,1000004,1000005,1000006,1000007,1000008,1000009,1000010], [1,1,1,1,1,1,1,1,1,1])

        // check that the token versions were updated
        // old tokens
        await expect(nftContractV3.ownerOf(1000001)).to.be.revertedWith('ERC721: invalid token ID')
        await expect(nftContractV3.ownerOf(1000002)).to.be.revertedWith('ERC721: invalid token ID')
        await expect(nftContractV3.ownerOf(1000003)).to.be.revertedWith('ERC721: invalid token ID')
        await expect(nftContractV3.ownerOf(1000004)).to.be.revertedWith('ERC721: invalid token ID')

        // new tokens
        expect(await nftContractV3.ownerOf(1010001)).to.equal(other.address)
        expect(await nftContractV3.ownerOf(1010002)).to.equal(other.address)
        expect(await nftContractV3.ownerOf(1010003)).to.equal(other.address)

    })

    it("Check batch claiming: can't claim with tokens not in snapshot", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(other.address)
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV3.address, 10 * price * (10 ** decimals))
        await nftContractV3.connect(other).mint(1, 5)


        // claim with being IDENT
        await claimContract.connect(platformManager).takeClaimingSnapshot(1)
        // mint further tokens not in snapshot
        await nftContractV3.connect(other).mint(1, 5)
        // athlete adds amount to distribution event 
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1)
        //add fan to IDENT
        await userManager.connect(kycManager).addAddressToIDENT(other.address)
        
        // claim batch
        await claimContract.connect(other).batchClaim([1000001,1000002,1000003,1000004,1000005], [1,1,1,1,1])
    
        // new tokens
        await expect(claimContract.connect(other).claim(1000006,1)).to.be.revertedWith('FantiumClaimingV1: token not allowed')
        await expect(claimContract.connect(other).batchClaim([1000006,1000007,1000008,1000009,1000010], [1,1,1,1,1])).to.be.revertedWith('FantiumClaimingV1: token not allowed')

        await expect(nftContractV3.ownerOf(1000004)).to.be.revertedWith('ERC721: invalid token ID')
        expect(await nftContractV3.ownerOf(1010004)).to.equal(other.address)
        expect(await nftContractV3.ownerOf(1000006)).to.equal(other.address)
        await expect(nftContractV3.ownerOf(1010006)).to.be.revertedWith('ERC721: invalid token ID')

    })

    it("Check claiming: try to claim without having paid in", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(other.address)
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV3.address, 10 * price * (10 ** decimals))
        await nftContractV3.connect(other).mint(1, 5)

        // claim with being IDENT
        await claimContract.connect(platformManager).takeClaimingSnapshot(1)
        // mint further tokens not in snapshot
        await nftContractV3.connect(other).mint(1, 5)
        // athlete adds amount to distribution event 
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        //add fan to IDENT
        await userManager.connect(kycManager).addAddressToIDENT(other.address)
        
        // new tokens
        await expect(claimContract.connect(other).claim(1000005,1)).to.be.revertedWith('FantiumClaimingV1: total distribution amount has not been paid in')

    })

    it("Check claiming: claim without start time past", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(other.address)
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV3.address, 10 * price * (10 ** decimals))
        await nftContractV3.connect(other).mint(1, 5)

        await claimContract.connect(platformManager).updateDistributionEventTimeStamps(1,1681699940,1681699941)

        // claim with being IDENT
        await claimContract.connect(platformManager).takeClaimingSnapshot(1)
        // mint further tokens not in snapshot
        await nftContractV3.connect(other).mint(1, 5)
        // athlete adds amount to distribution event 
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1)
        //add fan to IDENT
        await userManager.connect(kycManager).addAddressToIDENT(other.address)
        
        // new tokens
        await expect(claimContract.connect(other).claim(1000005,1)).to.be.revertedWith('FantiumClaimingV1: distribution time has not started or has ended')

    })

    it("Check claiming: claim with end time past", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(other.address)
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV3.address, 10 * price * (10 ** decimals))
        await nftContractV3.connect(other).mint(1, 5)

        const timestamp = await time.latest() + 1000;
        await claimContract.connect(platformManager).updateDistributionEventTimeStamps(1,1,timestamp)

        await time.increase(2000);

        // claim with being IDENT
        await claimContract.connect(platformManager).takeClaimingSnapshot(1)
        // mint further tokens not in snapshot
        await nftContractV3.connect(other).mint(1, 5)
        // athlete adds amount to distribution event 
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1)
        //add fan to IDENT
        await userManager.connect(kycManager).addAddressToIDENT(other.address)
        
        // new tokens
        await expect(claimContract.connect(other).claim(1000001,1)).to.be.revertedWith('FantiumClaimingV1: distribution time has not started or has ended')

    })

    it("Check claiming: revert wrong length of batch claim", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(other.address)
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV3.address, 10 * price * (10 ** decimals))
        await nftContractV3.connect(other).mint(1, 5)

        await expect(claimContract.connect(other).batchClaim([1000001,1000002,1000002],[1])).to.be.revertedWith('FantiumClaimingV1: Arrays must be of same length')
        const tokenNumbers = []
        const events = []
        for (let i = 0; i < 102; i++) {
            tokenNumbers.push(1000000+i)
            events.push(1)
        }
        
        await expect(claimContract.connect(other).batchClaim(tokenNumbers,events)).to.be.revertedWith('FantiumClaimingV1: Arrays must be of length <= 100')

    })

    it("Check claiming: check token allowed logic", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(other.address)
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV3.address, 10 * price * (10 ** decimals))
        await nftContractV3.connect(other).mint(1, 1)
        await nftContractV3.connect(other).mint(4, 1)
        await userManager.connect(kycManager).addAddressToIDENT(other.address)

        // claim with being IDENT
        await claimContract.connect(platformManager).takeClaimingSnapshot(1)
        // mint further tokens not in snapshot
        // athlete adds amount to distribution event 
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1)

        // check a token from a different distribution and a try twice with same token 
        await expect(claimContract.connect(other).claim(4000000,1)).to.be.revertedWith('FantiumClaimingV1: token not allowed')
        await claimContract.connect(other).claim(1000001,1)
        await expect(claimContract.connect(other).claim(1010001,1)).to.be.revertedWith('FantiumClaimingV1: token not allowed')

    })

    it("Check claiming: check token allowed logic", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3

        await nftContractV3.connect(platformManager).addCollection(
            athlete.address,
            primarySalePercentage,
            secondarySalePercentage,
            maxInvocations,
            price,
            timestamp,
            fantium.address,
            fantiumSecondaryBPS,
            0,
            0
        )
        await nftContractV3.connect(platformManager).toggleCollectionMintable(7)
        await nftContractV3.connect(platformManager).toggleCollectionPaused(7)

        await expect(claimContract.connect(platformManager).setupDistributionEvent(
            athlete.address,
            tournamentEarnings,
            otherEarnings,
            startTime,
            closeTime,
            [8],
            fantium.address,
            fantiumFeePBS
        )).to.be.rejectedWith("FantiumClaimingV1: Token has no earnings")

    })

    // UPDATE WITH SETTER FUNCTIONS   

    it("Check Update: Fantium NFT Contract", async () => {
        await claimContract.connect(platformManager).updateFantiumNFTContract(fan.address)
        expect(await claimContract.fantiumNFTContract()).to.equal(fan.address)

        await expect(claimContract.connect(platformManager).updateFantiumNFTContract(nullAddress)).to.be.revertedWith('Null address not allowed')

    })

    it("Check Update: Payout Token Contract", async () => {
        await claimContract.connect(platformManager).updatePayoutToken(fan.address)
        expect(await claimContract.payoutToken()).to.equal(fan.address)

        await expect(claimContract.connect(platformManager).updatePayoutToken(nullAddress)).to.be.revertedWith('Null address not allowed')
    })

    it("Check Update: Payout Token Contract with balance", async () => {

        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1)
        await expect(claimContract.connect(platformManager).updatePayoutToken(fan.address)).to.be.revertedWith('FantiumClaimingV1: has balance of current payoutToken')

    })

    it("Check Update: Fantium user Manager", async () => {

        await claimContract.connect(platformManager).updateFantiumUserManager(fan.address)
        expect(await claimContract.fantiumUserManager()).to.equal(fan.address)

        await expect(claimContract.connect(platformManager).updateFantiumUserManager(nullAddress)).to.be.revertedWith('Null address not allowed')

    })

})
