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
    const nullAddress = "0x000000"
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

    it("Check Setup: upgrading contract and minting NFTs on upgraded contract", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3 ) as FantiumNFTV3
        await nftContractV3.connect(platformManager).updateClaimContract(claimContract.address)
        await nftContractV3.connect(platformManager).updateUserManagerContract(userManager.address)
        await nftContractV3.connect(platformManager).updateCollectionSales(1,maxInvocations,price,tournamentEarningsShare1e7,otherEarningsShare1e7)

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

    ////////////////////////////////////////////

    it("Check Setup: upgrading NFTContract, create distributionEvent and pay in amount", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(platformManager).updateClaimContract(claimContract.address)
        await nftContractV3.connect(platformManager).updateUserManagerContract(userManager.address)
        await nftContractV3.connect(platformManager).updateCollectionSales(1,maxInvocations,price,tournamentEarningsShare1e7,otherEarningsShare1e7)

        // check name   
        expect(await nftContractV3.name()).to.equal("FANtium")

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

        expect((await claimContract.distributionEvents(1)).totalTournamentEarnings).to.equal(tournamentEarnings)
        expect((await claimContract.distributionEvents(1)).startTime).to.equal(startTime)
        expect((await claimContract.distributionEvents(1)).closeTime).to.equal(closeTime)
        expect((await claimContract.distributionEvents(1)).closed).to.equal(false)
        expect((await claimContract.distributionEvents(1)).distributionEventId).to.equal(1)
        expect((await claimContract.getDistributionEvent(1)).collectionIds[0]).to.equal(1)
        expect((await claimContract.getDistributionEvent(1)).collectionIds[1]).to.equal(2)
        expect((await claimContract.getDistributionEvent(1)).collectionIds[2]).to.equal(3)


        // KYC Fan
        await erc20Contract.connect(fan).approve(nftContract.address, 1 * price * (10 ** decimals))
        await userManager.connect(kycManager).addAddressToKYC(fan.address)
        await nftContractV3.connect(fan).mint(1, 1)
        await claimContract.connect(platformManager).takeClaimingSnapshot(1)
        expect((await claimContract.getDistributionEvent(1)).mintedTokens[0]).to.equal(1)
        expect((await claimContract.getDistributionEvent(1)).tournamentDistributionAmount).to.equal(tournamentEarnings * tournamentEarningsShare1e7 / 1e7)
        expect((await claimContract.getDistributionEvent(1)).otherDistributionAmount).to.equal(otherEarnings * otherEarningsShare1e7 / 1e7)

        // add distribution amount
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1)

        expect((await claimContract.getDistributionEvent(1)).amountPaidIn).to.equal((tournamentEarnings * tournamentEarningsShare1e7 / 1e7) + (otherEarnings * otherEarningsShare1e7 / 1e7))
        expect((await erc20Contract.balanceOf(claimContract.address))).to.equal((tournamentEarnings * tournamentEarningsShare1e7 / 1e7) + (otherEarnings * otherEarningsShare1e7 / 1e7))
    })

    ////////////////////////////////////////////

    it("Check Error: try to claim without token and fail", async () => {
        //upgrade and setup
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(platformManager).updateClaimContract(claimContract.address)
        await nftContractV3.connect(platformManager).updateUserManagerContract(userManager.address)
        await nftContractV3.connect(platformManager).updateCollectionSales(1,maxInvocations,price,tournamentEarningsShare1e7,otherEarningsShare1e7)

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

        //// 
        await expect(claimContract.connect(fan).claim(1000000, 1)).to.be.revertedWith('ERC721: invalid token ID')

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(athlete.address)

        // approve erc20 and mint
        await erc20Contract.connect(athlete).approve(nftContractV3.address, 3 * price * (10 ** decimals))
        await nftContractV3.connect(athlete).mint(1, 1)
        // add distribution amount
        await claimContract.connect(platformManager).takeClaimingSnapshot(1)
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1)

        await expect(claimContract.connect(fan).claim(1000000, 1)).to.be.revertedWith('FantiumClaimingV1: Only token owner')

    })

    ////////////////////////////////////////////

    it("Check single claiming: claim, receive amount and check calculation", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(platformManager).updateClaimContract(claimContract.address)
        await nftContractV3.connect(platformManager).updateUserManagerContract(userManager.address)
        await nftContractV3.connect(platformManager).updateCollectionSales(1,maxInvocations,price,tournamentEarningsShare1e7,otherEarningsShare1e7)

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(other.address)
        
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV3.address, price * (10 ** decimals))
        await nftContractV3.connect(other).mint(1, 1)

        //setup distribution event
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

        // athlete adds amount to distribution event 
        await claimContract.connect(platformManager).takeClaimingSnapshot(1)
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1)

        // claim without being IDENT 
        await expect(claimContract.connect(other).claim(1000000, 1)).to.be.revertedWith('FantiumClaimingV1: You are not ID verified')

        //add fan to IDENT
        await userManager.connect(platformManager).addAddressToIDENT(other.address)
        expect(await userManager.connect(platformManager).isAddressIDENT(other.address))

        // claim with being IDENT
        await claimContract.connect(other).claim(1000000, 1)

        // tournament amount * tokenshare (1000/1e7) / tournamentShareBPS (1000/10000) )
        expect((await(claimContract.getDistributionEvent(1))).claimedAmount).to.equal((tournamentEarnings * tournamentEarningsShare1e7 / 1e7) + (otherEarnings * otherEarningsShare1e7 / 1e7))
        
        const total_claim = (tournamentEarnings * tournamentEarningsShare1e7 / 1e7) + (otherEarnings * otherEarningsShare1e7 / 1e7)
        const fanClaim = total_claim * ((10000-fantiumFeePBS)/10000)
        const fantiumFee = total_claim * (fantiumFeePBS/10000)
        const fantiumBalance = fantiumFee + (1000000 * 10 ** decimals) + (price * (10 ** decimals) / 10)

        expect(await(erc20Contract.balanceOf(other.address))).to.equal((fanClaim) + (price * 9 * (10 ** decimals)))
        expect(await(erc20Contract.balanceOf(fantium.address))).to.equal(fantiumBalance)

        expect(await(erc20Contract.balanceOf(claimContract.address))).to.equal(0)

    })

//     ////////////////////////////////////////////

    it("Check batch claiming: claim, receive amount and check calculation", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(platformManager).updateClaimContract(claimContract.address)
        await nftContractV3.connect(platformManager).updateUserManagerContract(userManager.address)
        await nftContractV3.connect(platformManager).updateCollectionSales(1,maxInvocations,price,tournamentEarningsShare1e7,otherEarningsShare1e7)

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(other.address)
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV3.address, 10 * price * (10 ** decimals))
        await nftContractV3.connect(other).mint(1, 10)

        //setup distribution event
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

        // claim with being IDENT
        await claimContract.connect(platformManager).takeClaimingSnapshot(1)
        // athlete adds amount to distribution event 
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1)

        // claim without being IDENT
        await expect(claimContract.connect(other).claim(1000000, 1)).to.be.revertedWith('FantiumClaimingV1: You are not ID verified')
        //add fan to IDENT
        await userManager.connect(kycManager).addAddressToIDENT(other.address)
        expect(await userManager.connect(kycManager).isAddressIDENT(other.address))
        await claimContract.connect(other).batchClaim([1000000,1000001,1000002,1000003,1000004,1000005,1000006,1000007,1000008,1000009], [1,1,1,1,1,1,1,1,1,1])

        const totalClaim = 10 * ((tournamentEarnings * tournamentEarningsShare1e7 / 1e7) + (otherEarnings * otherEarningsShare1e7 / 1e7))
        const fanClaim = totalClaim * ((10000-fantiumFeePBS)/10000)
        const fantiumFee = totalClaim * (fantiumFeePBS/10000)
        const fantiumBalance = fantiumFee + (1000000 * 10 ** decimals) + (10 * price * (10 ** decimals) / 10)
        
        expect((await(claimContract.getDistributionEvent(1))).claimedAmount).to.equal(totalClaim)
        expect((await(claimContract.getDistributionEvent(1))).amountPaidIn).to.equal(totalClaim)
        expect((await(claimContract.getDistributionEvent(1))).tournamentDistributionAmount).to.equal(10 * tournamentEarnings * tournamentEarningsShare1e7 / 1e7)
        expect((await(claimContract.getDistributionEvent(1))).otherDistributionAmount).to.equal(10 * otherEarnings * otherEarningsShare1e7 / 1e7)
        
        expect(await(erc20Contract.balanceOf(other.address))).to.equal(fanClaim)
        expect(await(erc20Contract.balanceOf(fantium.address))).to.equal(fantiumBalance)

        expect(await(erc20Contract.balanceOf(claimContract.address))).to.equal(0)

    })
    


//     ////// BATCH ALLOWLISTING

    it("Check UserManager Contract: batch allowlist 1000 addresses with allocations", async () => {
        /// DEPLOY V2
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(platformManager).updateClaimContract(claimContract.address)
        await nftContractV3.connect(platformManager).updateUserManagerContract(userManager.address)
        

        /// ADMIN ON V1
        // add fan address to KYC
        await userManager.connect(platformManager).addAddressToKYC(fan.address)
        // unpause collection minting


        // create 1000 addresses and allocations
        const addresses = []
        const allocations = []
        for (let i = 0; i < 500; i++) {
            addresses.push(await ethers.Wallet.createRandom().address)
            allocations.push(5)
        }

        /// ADMIN
        // batch allowlist
        await userManager.connect(platformManager).batchAllowlist(1, nftContractV3.address,addresses, allocations)

        // check if allowlist is correct
        for (let i = 0; i < 500; i++) {
            expect(await userManager.hasAllowlist(nftContractV3.address, 1,addresses[i])).to.equal(5)
        }
    })



    ////// BATCH MINTING

    it("checks that FAN can batch mint 10 NFTs if collection is Mintable and Unpaused", async () => {
        /// DEPLOY VV
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(platformManager).updateClaimContract(claimContract.address)
        await nftContractV3.connect(platformManager).updateUserManagerContract(userManager.address)
        await nftContractV3.connect(platformManager).updateCollectionSales(1,maxInvocations,price,tournamentEarningsShare1e7,otherEarningsShare1e7)


        /// ADMIN ON V1
        // add fan address to KYC
        await userManager.connect(kycManager).addAddressToKYC(fan.address)
        // unpause collection minting
        await nftContractV3.connect(platformManager).updateUserManagerContract(userManager.address)
        // check if fan can mint
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals * 10)
        await nftContractV3.connect(fan).mint(1, 10);

        /// 
        expect(await nftContractV3.balanceOf(fan.address)).to.equal(10)
    })

    // check that FAN can't mint if collection is not Mintable
    it("checks that FAN can't mint if collection is not Mintable", async () => {
        /// DEPLOY V2
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(platformManager).updateClaimContract(claimContract.address)
        await nftContractV3.connect(platformManager).updateUserManagerContract(userManager.address)

        // make collection not mintable
        await nftContractV3.connect(platformManager).toggleCollectionMintable(1)
        
        /// ADMIN ON V1
        // add fan address to KYC
        await userManager.connect(kycManager).addAddressToKYC(fan.address)
        // unpause collection minting
        
        // check if fan can mint
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals)
        await expect(nftContractV3.connect(fan).mint(1, 10)).to.be.revertedWith("Collection is not mintable")
    })

    // check that FAN can mint if collection is Mintable, Paused and has sufficient allowlist allocation
    it("checks that FAN can mint if collection is Mintable, Paused and has sufficient allowlist allocation", async () => {
        /// DEPLOY V2
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(platformManager).updateClaimContract(claimContract.address)
        await nftContractV3.connect(platformManager).updateUserManagerContract(userManager.address)

        /// ADMIN ON V1
        // add fan address to KYC
        await userManager.connect(kycManager).addAddressToKYC(fan.address)
        
        // setting collection paused
        await nftContract.connect(platformManager).toggleCollectionPaused(1)
        // set allowlist allocation 
        await userManager.connect(platformManager).batchAllowlist(1, nftContractV3.address ,[fan.address], [10])

        // allocation
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals * 10)

        await nftContractV3.connect(fan).mint(1, 10);
        /// 
        expect(await nftContractV3.balanceOf(fan.address)).to.equal(10)

        // check that tokenIds are minted
        expect(await nftContractV3.tokenURI(1000000)).to.equal("https://contract.com/1000000")

    })

    it("Check batch claiming: update of tokenVersion and tokenID", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(platformManager).updateClaimContract(claimContract.address)
        await nftContractV3.connect(platformManager).updateUserManagerContract(userManager.address)
        await nftContractV3.connect(platformManager).updateCollectionSales(1,maxInvocations,price,tournamentEarningsShare1e7,otherEarningsShare1e7)

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(other.address)
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV3.address, 10 * price * (10 ** decimals))
        await nftContractV3.connect(other).mint(1, 10)

        //setup distribution event
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

        // claim with being IDENT
        await claimContract.connect(platformManager).takeClaimingSnapshot(1)
        // athlete adds amount to distribution event 
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1)

        // claim without being IDENT
        await expect(claimContract.connect(other).claim(1000000, 1)).to.be.revertedWith('FantiumClaimingV1: You are not ID verified')
        //add fan to IDENT
        await userManager.connect(kycManager).addAddressToIDENT(other.address)
        
        // claim batch
        await claimContract.connect(other).batchClaim([1000000,1000001,1000002,1000003,1000004,1000005,1000006,1000007,1000008,1000009], [1,1,1,1,1,1,1,1,1,1])

        // check that the token versions were updated
        // old tokens
        await expect(nftContractV3.ownerOf(1000000)).to.be.revertedWith('ERC721: invalid token ID')
        await expect(nftContractV3.ownerOf(1000001)).to.be.revertedWith('ERC721: invalid token ID')
        await expect(nftContractV3.ownerOf(1000002)).to.be.revertedWith('ERC721: invalid token ID')
        await expect(nftContractV3.ownerOf(1000003)).to.be.revertedWith('ERC721: invalid token ID')

        // new tokens
        expect(await nftContractV3.ownerOf(1010000)).to.equal(other.address)
        expect(await nftContractV3.ownerOf(1010001)).to.equal(other.address)
        expect(await nftContractV3.ownerOf(1010002)).to.equal(other.address)

    })


    it("Check batch claiming: can't claim with tokens not in snapshot", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(platformManager).updateClaimContract(claimContract.address)
        await nftContractV3.connect(platformManager).updateUserManagerContract(userManager.address)
        await nftContractV3.connect(platformManager).updateCollectionSales(1,maxInvocations,price,tournamentEarningsShare1e7,otherEarningsShare1e7)

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(other.address)
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV3.address, 10 * price * (10 ** decimals))
        await nftContractV3.connect(other).mint(1, 5)

        //setup distribution event
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
        await claimContract.connect(other).batchClaim([1000000,1000001,1000002,1000003,1000004], [1,1,1,1,1])

        // new tokens
        await expect(claimContract.connect(other).claim(1000005,1)).to.be.revertedWith('FantiumClaimingV1: token not allowed')
        await expect(claimContract.connect(other).batchClaim([1000005,1000006,1000007,1000008,1000009], [1,1,1,1,1])).to.be.revertedWith('FantiumClaimingV1: token not allowed')

        await expect(nftContractV3.ownerOf(1000004)).to.be.revertedWith('ERC721: invalid token ID')
        expect(await nftContractV3.ownerOf(1010004)).to.equal(other.address)
        expect(await nftContractV3.ownerOf(1000005)).to.equal(other.address)
        await expect(nftContractV3.ownerOf(1010005)).to.be.revertedWith('ERC721: invalid token ID')

    })



    it("Check claiming: try to claim without having paid in", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3")
        const nftContractV3 = await upgrades.upgradeProxy(nftContract.address, fanV3) as FantiumNFTV3
        await nftContractV3.connect(platformManager).updateClaimContract(claimContract.address)
        await nftContractV3.connect(platformManager).updateUserManagerContract(userManager.address)
        await nftContractV3.connect(platformManager).updateCollectionSales(1,maxInvocations,price,tournamentEarningsShare1e7,otherEarningsShare1e7)

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(other.address)
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV3.address, 10 * price * (10 ** decimals))
        await nftContractV3.connect(other).mint(1, 5)

        //setup distribution event
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
        await nftContractV3.connect(platformManager).updateClaimContract(claimContract.address)
        await nftContractV3.connect(platformManager).updateUserManagerContract(userManager.address)
        await nftContractV3.connect(platformManager).updateCollectionSales(1,maxInvocations,price,tournamentEarningsShare1e7,otherEarningsShare1e7)

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(other.address)
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV3.address, 10 * price * (10 ** decimals))
        await nftContractV3.connect(other).mint(1, 5)

        //setup distribution event
        await claimContract.connect(platformManager).setupDistributionEvent(
            athlete.address,
            tournamentEarnings,
            otherEarnings,
            1780123335,
            closeTime,
            [1,2,3],
            fantium.address,
            fantiumFeePBS
        )

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
        await nftContractV3.connect(platformManager).updateClaimContract(claimContract.address)
        await nftContractV3.connect(platformManager).updateUserManagerContract(userManager.address)
        await nftContractV3.connect(platformManager).updateCollectionSales(1,maxInvocations,price,tournamentEarningsShare1e7,otherEarningsShare1e7)

        // add platfrom manager to KYC
        await userManager.connect(kycManager).addAddressToKYC(other.address)
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV3.address, 10 * price * (10 ** decimals))
        await nftContractV3.connect(other).mint(1, 5)

        const timestamp = await time.latest() + 1000;


        //setup distribution event
        await claimContract.connect(platformManager).setupDistributionEvent(
            athlete.address,
            tournamentEarnings,
            otherEarnings,
            startTime,
            timestamp,
            [1,2,3],
            fantium.address,
            fantiumFeePBS
        )

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
        await expect(claimContract.connect(other).claim(1000000,1)).to.be.revertedWith('FantiumClaimingV1: distribution time has not started or has ended')

    })


})


