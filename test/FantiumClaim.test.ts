import { ethers, upgrades } from 'hardhat'
import { expect } from 'chai'
import { beforeEach } from 'mocha'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { FantiumNFTV2 } from '../typechain-types/contracts/FantiumNFTV2'
import { FantiumNFTV4 } from '../typechain-types/contracts/FantiumNFTV4'
import { FantiumClaimingV1} from '../typechain-types/contracts/claiming/FantiumClaimingV1'
import {FantiumUserManager} from '../typechain-types/contracts/utils/FantiumUserManager'
import { Mock20 } from '../typechain-types/contracts/mocks/Mock20'
import { erc20 } from '../typechain-types/@openzeppelin/contracts/token'

describe("FantiumClaim", () => {

    let nftContract: FantiumNFTV2
    let nftContractV4: FantiumNFTV4
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
    const tournamentAmount = 50000000000 // in 50,000 USDC without decimals
    const tournamentTokenShareBPS = 1000 // 10%
    const otherEarningsShare1e7 = 100000 // 0.1%
    const otherAmount = 50000000000 // in 50,000 USDC without decimals 
    const otherTokenShareBPS = 1000 // 10%
    const totalAmount = tournamentAmount + otherAmount
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
        await erc20Contract.connect(fan).transfer(other.address, 10 * 10 ** decimals)
        
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


        /*//////////////////////////////////////////////////////////////
                        SETUP CLAIMING CONTRACT
        //////////////////////////////////////////////////////////////*/

        const FantiumClaimingV1 = await ethers.getContractFactory("FantiumClaimingV1")
        claimContract = await upgrades.deployProxy(FantiumClaimingV1, [erc20Contract.address, nftContract.address, defaultAdmin.address], { constructorArgs: [forwarder.address] }) as FantiumClaimingV1

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
        await claimContract.connect(platformManager).updateFantiumUserManager(userManager.address)

    })

    ////////////////////////////////////////////

    it("Check Setup: upgrading contract and minting NFTs on upgraded contract", async () => {
        const fanV4 = await ethers.getContractFactory("FantiumNFTV4")
        const nftContractV4 = await upgrades.upgradeProxy(nftContract.address, fanV4) as FantiumNFTV4

        // add first collection
        for (let i = 0; i < 4; i++) {
            await nftContractV4.connect(platformManager).addCollection(
                athlete.address,
                primarySalePercentage,
                secondarySalePercentage,
                maxInvocations,
                price,
                tournamentEarningsShare1e7,
                timestamp,
                fantium.address,
                fantiumSecondaryBPS,
                otherEarningsShare1e7
            )
        }

        // check name   
        expect(await nftContractV4.name()).to.equal("FANtium")

        // toggle and unpause collection mintable
        await nftContractV4.connect(platformManager).toggleCollectionMintable(1)
        await nftContractV4.connect(platformManager).toggleCollectionPaused(1)

        // add platfrom manager to KYC
        await nftContractV4.connect(kycManager).addAddressToKYC(fan.address)

        // approve erc20
        await erc20Contract.connect(fan).approve(nftContractV4.address, 3 * price * (10 ** decimals))

        // default admin mint a token
        await nftContractV4.connect(fan).batchMint(1, 3)

        // check balance
        expect(await nftContractV4.balanceOf(fan.address)).to.equal(3)
    })

    ////////////////////////////////////////////

    it("Check Setup: upgrading NFTContract, create distributionEvent and pay in amount", async () => {
        const fanV4 = await ethers.getContractFactory("FantiumNFTV4")
        const nftContractV4 = await upgrades.upgradeProxy(nftContract.address, fanV4) as FantiumNFTV4

        // add first collection
        for (let i = 0; i < 4; i++) {
            await nftContractV4.connect(platformManager).addCollection(
                athlete.address,
                primarySalePercentage,
                secondarySalePercentage,
                maxInvocations,
                price,
                tournamentEarningsShare1e7,
                timestamp,
                fantium.address,
                fantiumSecondaryBPS,
                otherEarningsShare1e7
            )
        }

        // check name   
        expect(await nftContractV4.name()).to.equal("FANtium")

        await claimContract.connect(platformManager).setupDistributionEvent(
            athlete.address,
            tournamentAmount,
            tournamentTokenShareBPS,
            otherAmount,
            otherTokenShareBPS,
            startTime,
            closeTime,
            [1,2,3],
            fantium.address,
            fantiumFeePBS
        )

        expect((await claimContract.distributionEvents(1)).tournamentDistributionAmount).to.equal(tournamentAmount)
        expect((await claimContract.distributionEvents(1)).startTime).to.equal(startTime)
        expect((await claimContract.distributionEvents(1)).closeTime).to.equal(closeTime)
        expect((await claimContract.distributionEvents(1)).closed).to.equal(false)
        expect((await claimContract.distributionEvents(1)).distributionEventId).to.equal(1)
        expect((await claimContract.getDistributionEvent(1)).collectionIds[0]).to.equal(1)
        expect((await claimContract.getDistributionEvent(1)).collectionIds[1]).to.equal(2)
        expect((await claimContract.getDistributionEvent(1)).collectionIds[2]).to.equal(3)

        await expect(claimContract.connect(athlete).addDistributionAmount(1, 10)).to.be.revertedWith('FantiumClaimingV1: amount must be equal to distribution amount')
        // approve erc20
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1, totalAmount)

        expect((await claimContract.getDistributionEvent(1)).amountPaidIn).to.equal(true)
        expect((await erc20Contract.balanceOf(claimContract.address))).to.equal(100000 * (10 ** decimals))
    })

    ////////////////////////////////////////////

    it("Check Error: try to claim without token and fail", async () => {
        const fanV4 = await ethers.getContractFactory("FantiumNFTV4")
        const nftContractV4 = await upgrades.upgradeProxy(nftContract.address, fanV4) as FantiumNFTV4

        // add first collection
        for (let i = 0; i < 4; i++) {
            await nftContractV4.connect(platformManager).addCollection(
                athlete.address,
                primarySalePercentage,
                secondarySalePercentage,
                maxInvocations,
                price,
                tournamentEarningsShare1e7,
                timestamp,
                fantium.address,
                fantiumSecondaryBPS,
                otherEarningsShare1e7
            )
        }

        await claimContract.connect(platformManager).setupDistributionEvent(
            athlete.address,
            tournamentAmount,
            tournamentTokenShareBPS,
            otherAmount,
            otherTokenShareBPS,
            startTime,
            closeTime,
            [1,2,3],
            fantium.address,
            fantiumFeePBS
        )

        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1, totalAmount)

        await expect(claimContract.connect(fan).claim(1000000, 1)).to.be.revertedWith('ERC721: invalid token ID')
        await nftContractV4.connect(platformManager).toggleCollectionMintable(1)
        await nftContractV4.connect(platformManager).toggleCollectionPaused(1)
        // add platfrom manager to KYC
        await nftContractV4.connect(kycManager).addAddressToKYC(athlete.address)
        // approve erc20
        await erc20Contract.connect(athlete).approve(nftContractV4.address, 3 * price * (10 ** decimals))
        
        await nftContractV4.connect(athlete).batchMint(1, 1)

        await expect(claimContract.connect(fan).claim(1000000, 1)).to.be.revertedWith('Only token owner')

    })

    ////////////////////////////////////////////

    it("Check single claiming: claim, receive amount and check calculation", async () => {
        const fanV4 = await ethers.getContractFactory("FantiumNFTV4")
        const nftContractV4 = await upgrades.upgradeProxy(nftContract.address, fanV4) as FantiumNFTV4
        await nftContractV4.connect(platformManager).updateClaimContract(claimContract.address)

        // add first collection
        for (let i = 0; i < 4; i++) {
            await nftContractV4.connect(platformManager).addCollection(
                athlete.address,
                primarySalePercentage,
                secondarySalePercentage,
                maxInvocations,
                price,
                tournamentEarningsShare1e7,
                timestamp,
                fantium.address,
                fantiumSecondaryBPS,
                otherEarningsShare1e7
            )
        }

        //setup collection
        await nftContractV4.connect(platformManager).toggleCollectionMintable(1)
        await nftContractV4.connect(platformManager).toggleCollectionPaused(1)
        // add platfrom manager to KYC
        await nftContractV4.connect(kycManager).addAddressToKYC(other.address)
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV4.address, price * (10 ** decimals))
        await nftContractV4.connect(other).batchMint(1, 1)

        //setup distribution event
        await claimContract.connect(platformManager).setupDistributionEvent(
            athlete.address,
            tournamentAmount,
            tournamentTokenShareBPS,
            otherAmount,
            otherTokenShareBPS,
            startTime,
            closeTime,
            [1,2,3],
            fantium.address,
            fantiumFeePBS
        )

        // athlete adds amount to distribution event 
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1, totalAmount)

        // claim without being IDENT 
        await expect(claimContract.connect(other).claim(1000000, 1)).to.be.revertedWith('FantiumClaimingV1: You are not ID verified')

        //add fan to IDENT
        await userManager.connect(platformManager).addAddressToIDENT(other.address)
        expect(await userManager.connect(platformManager).isAddressIDENT(other.address))

        // claim with being IDENT
        await claimContract.connect(other).claim(1000000, 1)

        // tournament amount * tokenshare (1000/1e7) / tournamentShareBPS (1000/10000) )
        expect((await(claimContract.getDistributionEvent(1))).claimedAmount).to.equal((tournamentAmount * tournamentEarningsShare1e7 * 10000 / 1e7 / tournamentTokenShareBPS) + (otherAmount * otherEarningsShare1e7 * 10000 / 1e7 / otherTokenShareBPS))
        
        const tournamentClaim = (tournamentAmount * tournamentEarningsShare1e7  * 10000 / 1e7 / tournamentTokenShareBPS) - (tournamentAmount *  tournamentEarningsShare1e7 * fantiumFeePBS * 10000 / 10000 / 1e7 / tournamentTokenShareBPS)
        const otherClaim = (otherAmount * otherEarningsShare1e7 * 10000 / 1e7 / otherTokenShareBPS) - (otherAmount *  otherEarningsShare1e7 * fantiumFeePBS * 10000 / 10000 / 1e7 / otherTokenShareBPS)

        expect(await(erc20Contract.balanceOf(other.address))).to.equal((tournamentClaim + otherClaim) + (price * 9 * (10 ** decimals)))

        expect(await(erc20Contract.balanceOf(claimContract.address))).to.equal(((totalAmount) - ((tournamentAmount) * tournamentEarningsShare1e7 * 10000 / tournamentTokenShareBPS / 1e7)) - ((otherAmount) * otherEarningsShare1e7 * 10000 / otherTokenShareBPS / 1e7))

    })

    ////////////////////////////////////////////

    it("Check batch claiming: claim, receive amount and check calculation", async () => {
        const fanV4 = await ethers.getContractFactory("FantiumNFTV4")
        const nftContractV4 = await upgrades.upgradeProxy(nftContract.address, fanV4) as FantiumNFTV4
        await nftContractV4.connect(platformManager).updateClaimContract(claimContract.address)

        // add first collection
        for (let i = 0; i < 4; i++) {
            await nftContractV4.connect(platformManager).addCollection(
                athlete.address,
                primarySalePercentage,
                secondarySalePercentage,
                maxInvocations,
                price,
                tournamentEarningsShare1e7,
                timestamp,
                fantium.address,
                fantiumSecondaryBPS,
                otherEarningsShare1e7
            )
        }

        //setup collection
        await nftContractV4.connect(platformManager).toggleCollectionMintable(1)
        await nftContractV4.connect(platformManager).toggleCollectionPaused(1)
        // add platfrom manager to KYC
        await nftContractV4.connect(kycManager).addAddressToKYC(other.address)
        // approve erc20
        await erc20Contract.connect(other).approve(nftContractV4.address, 10 * price * (10 ** decimals))
        await nftContractV4.connect(other).batchMint(1, 10)

        //setup distribution event
        await claimContract.connect(platformManager).setupDistributionEvent(
            athlete.address,
            tournamentAmount,
            tournamentTokenShareBPS,
            otherAmount,
            otherTokenShareBPS,
            startTime,
            closeTime,
            [1,2,3],
            fantium.address,
            fantiumFeePBS
        )

        // athlete adds amount to distribution event 
        await erc20Contract.connect(athlete).approve(claimContract.address, totalAmount)
        await claimContract.connect(athlete).addDistributionAmount(1, totalAmount)

        // claim without being IDENT
        await expect(claimContract.connect(other).claim(1000000, 1)).to.be.revertedWith('FantiumClaimingV1: You are not ID verified')

        //add fan to IDENT
        await userManager.connect(platformManager).addAddressToIDENT(other.address)
        expect(await userManager.connect(platformManager).isAddressIDENT(other.address))

        // claim with being IDENT
        await claimContract.connect(other).batchClaim([1000000,1000001,1000002,1000003,1000004,1000005,1000006,1000007,1000008,1000009], [1,1,1,1,1,1,1,1,1,1])
        
        expect((await(claimContract.getDistributionEvent(1))).claimedAmount).to.equal(10 * ((tournamentAmount * tournamentEarningsShare1e7 * 10000 / 1e7 / tournamentTokenShareBPS) + (otherAmount * otherEarningsShare1e7 * 10000 / 1e7 / otherTokenShareBPS)))
        
        const tournamentClaim = (tournamentAmount * tournamentEarningsShare1e7  * 10000 / 1e7 / tournamentTokenShareBPS) - (tournamentAmount *  tournamentEarningsShare1e7 * fantiumFeePBS * 10000 / 10000 / 1e7 / tournamentTokenShareBPS)
        const otherClaim = (otherAmount * otherEarningsShare1e7 * 10000 / 1e7 / otherTokenShareBPS) - (otherAmount *  otherEarningsShare1e7 * fantiumFeePBS * 10000 / 10000 / 1e7 / otherTokenShareBPS)

        expect(await(erc20Contract.balanceOf(other.address))).to.equal(10 * (tournamentClaim + otherClaim))

        expect(await(erc20Contract.balanceOf(claimContract.address))).to.equal(0)

    })
    


//     ////// BATCH ALLOWLISTING

    it("Check UserManager Contract: batch allowlist 1000 addresses with allocations", async () => {
        /// DEPLOY V2
        const fanV4 = await ethers.getContractFactory("FantiumNFTV4")
        const nftContractV4 = await upgrades.upgradeProxy(nftContract.address, fanV4) as FantiumNFTV4

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
        await userManager.connect(platformManager).batchAllowlist(1, nftContractV4.address,addresses, allocations)

        // check if allowlist is correct
        for (let i = 0; i < 500; i++) {
            expect(await userManager.hasAllowlist(nftContractV4.address, 1,addresses[i])).to.equal(5)
        }
    })



//     ////// BATCH MINTING

    it("checks that FAN can batch mint 10 NFTs if collection is Mintable and Unpaused", async () => {
        /// DEPLOY V2
        const fanV4 = await ethers.getContractFactory("FantiumNFTV4")
        const nftContractV4 = await upgrades.upgradeProxy(nftContract.address, fanV4) as FantiumNFTV4
        // add first collection
        for (let i = 0; i < 4; i++) {
            await nftContractV4.connect(platformManager).addCollection(
                athlete.address,
                primarySalePercentage,
                secondarySalePercentage,
                maxInvocations,
                price,
                tournamentEarningsShare1e7,
                timestamp,
                fantium.address,
                fantiumSecondaryBPS,
                otherEarningsShare1e7
            )
        }

        /// ADMIN ON V1
        // add fan address to KYC
        await nftContractV4.connect(kycManager).addAddressToKYC(fan.address)
        // unpause collection minting
        await nftContractV4.connect(platformManager).toggleCollectionPaused(1)
        await nftContractV4.connect(platformManager).toggleCollectionMintable(1)
        // check if fan can mint
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals * 10)
        await nftContractV4.connect(fan).batchMint(1, 10);

        /// 
        expect(await nftContractV4.balanceOf(fan.address)).to.equal(10)
    })

    // check that FAN can't mint if collection is not Mintable
    it("checks that FAN can't mint if collection is not Mintable", async () => {
        /// DEPLOY V2
        const fanV4 = await ethers.getContractFactory("FantiumNFTV4")
        const nftContractV4 = await upgrades.upgradeProxy(nftContract.address, fanV4) as FantiumNFTV4
        // add first collection
        for (let i = 0; i < 4; i++) {
            await nftContractV4.connect(platformManager).addCollection(
                athlete.address,
                primarySalePercentage,
                secondarySalePercentage,
                maxInvocations,
                price,
                tournamentEarningsShare1e7,
                timestamp,
                fantium.address,
                fantiumSecondaryBPS,
                otherEarningsShare1e7
            )
        }

        /// ADMIN ON V1
        // add fan address to KYC
        await nftContractV4.connect(kycManager).addAddressToKYC(fan.address)
        // unpause collection minting
        await nftContractV4.connect(platformManager).toggleCollectionPaused(1)
        // check if fan can mint
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals)
        await expect(nftContractV4.connect(fan).batchMint(1, 10)).to.be.revertedWith("Collection is not mintable")
    })

    // check that FAN can mint if collection is Mintable, Paused and has sufficient allowlist allocation
    it("checks that FAN can mint if collection is Mintable, Paused and has sufficient allowlist allocation", async () => {
        /// DEPLOY V2
        const fanV4 = await ethers.getContractFactory("FantiumNFTV4")
        const nftContractV4 = await upgrades.upgradeProxy(nftContract.address, fanV4) as FantiumNFTV4
        // add first collection
        for (let i = 0; i < 4; i++) {
            await nftContractV4.connect(platformManager).addCollection(
                athlete.address,
                primarySalePercentage,
                secondarySalePercentage,
                maxInvocations,
                price,
                tournamentEarningsShare1e7,
                timestamp,
                fantium.address,
                fantiumSecondaryBPS,
                otherEarningsShare1e7
            )
        }

        /// ADMIN ON V1
        // add fan address to KYC
        await nftContractV4.connect(kycManager).addAddressToKYC(fan.address)
        // unpause collection minting
        await nftContractV4.connect(platformManager).toggleCollectionMintable(1)
        // set allowlist allocation
        await nftContractV4.connect(platformManager).batchAllowlist(1, [fan.address], [10])

        // allocation
        await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals * 10)

        await nftContractV4.connect(fan).batchMint(1, 10);
        /// 
        expect(await nftContractV4.balanceOf(fan.address)).to.equal(10)

        // check that tokenIds are minted
        expect(await nftContractV4.tokenURI(1000000)).to.equal("https://contract.com/1000000")

    })
})


