import { ethers, upgrades } from 'hardhat'
import { expect } from 'chai'
import { beforeEach } from 'mocha'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { FantiumNFTV2 } from '../typechain-types/contracts/FantiumNFTV2'
import { FantiumNFTV4 } from '../typechain-types/contracts/FantiumNFTV4'
import { FantiumClaimingV1} from '../typechain-types/contracts/claiming/FantiumClaimingV1'
import { Mock20 } from '../typechain-types/contracts/mocks/Mock20'

describe("FantiumClaim", () => {

    let nftContract: FantiumNFTV2
    let nftContractV4: FantiumNFTV4
    let claimContract: FantiumClaimingV1
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
    const maxInvocations = 100
    const price = 100
    const earningsSplit = 10
    let timestamp = 1
    let decimals = 18
    let fantiumSecondaryBPS = 250
    let fantiumFeePBS = 250
    let fantiumTransactionFeeInWei = ethers.BigNumber.from(1000000000000000)

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
        
        // set decoimals
        decimals = await erc20Contract.decimals()

        const fanV4 = await ethers.getContractFactory("FantiumNFTV4")
        const nftContractV4 = await upgrades.upgradeProxy(nftContract.address, fanV4, { constructorArgs: [forwarder.address]}) as FantiumNFTV4

        /*//////////////////////////////////////////////////////////////
                        SETUP CLAIMING CONTRACT
        //////////////////////////////////////////////////////////////*/

        const FantiumClaimingV1 = await ethers.getContractFactory("FantiumClaimingV1")
        claimContract = await upgrades.deployProxy(FantiumClaimingV1, [erc20Contract.address, nftContract.address, defaultAdmin.address], { constructorArgs: [forwarder.address]  }) as FantiumClaimingV1

        // set Role
        await claimContract.connect(defaultAdmin).grantRole(await claimContract.PLATFORM_MANAGER_ROLE(), platformManager.address)

        // pause the contract
        await claimContract.connect(platformManager).pause()
        // unpause contract
        await claimContract.connect(platformManager).unpause()

    })

    it("checks that we can deploy upgrade", async () => {

        // await claimContract.connect(platformManager).setupDistributionEvent(
        //     athlete.address,
        //     100000,
        //     timestamp,
        //     [1,2,3],
        //     fantium.address,
        //     fantiumFeePBS,
        //     fantiumTransactionFeeInWei
        // )


        // // check name   
        // expect(await nftContractV4.name()).to.equal("FANtium")

        // // toggle and unpause collection mintable
        // await nftContractV4.connect(platformManager).toggleCollectionMintable(1)
        // await nftContractV4.connect(platformManager).toggleCollectionPaused(1)

        // // add platfrom manager to KYC
        // await nftContractV4.connect(kycManager).addAddressToKYC(fan.address)

        // // approve erc20
        // await erc20Contract.connect(fan).approve(nftContractV4.address, 3 * price * (10 ** decimals))

        // // default admin mint a token
        // await nftContractV4.connect(fan).batchMint(1, 3)

        // // check balance
        // expect(await nftContractV4.balanceOf(fan.address)).to.equal(3)
    })



//     ////// BATCH ALLOWLISTING

//     it("checks that PM can batch allowlist 1000 addresses with allocations", async () => {
//         /// DEPLOY V2
//         const fanV4 = await ethers.getContractFactory("FantiumNFTV4")
//         const nftContractV4 = await upgrades.upgradeProxy(nftContract.address, fanV4) as FantiumNFTV4

//         /// ADMIN ON V1
//         // add fan address to KYC
//         await nftContractV4.connect(kycManager).addAddressToKYC(fan.address)
//         // unpause collection minting


//         // create 1000 addresses and allocations
//         const addresses = []
//         const allocations = []
//         for (let i = 0; i < 500; i++) {
//             addresses.push(await ethers.Wallet.createRandom().address)
//             allocations.push(5)
//         }

//         /// ADMIN
//         // batch allowlist
//         await nftContractV4.connect(platformManager).batchAllowlist(1, addresses, allocations)

//         // check if allowlist is correct
//         for (let i = 0; i < 500; i++) {
//             // expect(await nftContractV4.collectionIdToAllowList(1, addresses[i])
//             // console.log(allowlist)
//         }
//     })



//     ////// BATCH MINTING

//     it("checks that FAN can batch mint 10 NFTs if collection is Mintable and Unpaused", async () => {
//         /// DEPLOY V2
//         const fanV4 = await ethers.getContractFactory("FantiumNFTV4")
//         const nftContractV4 = await upgrades.upgradeProxy(nftContract.address, fanV4) as FantiumNFTV4

//         /// ADMIN ON V1
//         // add fan address to KYC
//         await nftContractV4.connect(kycManager).addAddressToKYC(fan.address)
//         // unpause collection minting
//         await nftContractV4.connect(platformManager).toggleCollectionPaused(1)
//         await nftContractV4.connect(platformManager).toggleCollectionMintable(1)
//         // check if fan can mint
//         await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals * 10)
//         await nftContractV4.connect(fan).batchMint(1, 10);

//         /// 
//         expect(await nftContractV4.balanceOf(fan.address)).to.equal(10)
//     })

//     // check that FAN can't mint if collection is not Mintable
//     it("checks that FAN can't mint if collection is not Mintable", async () => {
//         /// DEPLOY V2
//         const fanV4 = await ethers.getContractFactory("FantiumNFTV4")
//         const nftContractV4 = await upgrades.upgradeProxy(nftContract.address, fanV4) as FantiumNFTV4

//         /// ADMIN ON V1
//         // add fan address to KYC
//         await nftContractV4.connect(kycManager).addAddressToKYC(fan.address)
//         // unpause collection minting
//         await nftContractV4.connect(platformManager).toggleCollectionPaused(1)
//         // check if fan can mint
//         await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals)
//         await expect(nftContractV4.connect(fan).batchMint(1, 10)).to.be.revertedWith("Collection is not mintable")
//     })

//     // check that FAN can mint if collection is Mintable, Paused and has sufficient allowlist allocation
//     it("checks that FAN can mint if collection is Mintable, Paused and has sufficient allowlist allocation", async () => {
//         /// DEPLOY V2
//         const fanV4 = await ethers.getContractFactory("FantiumNFTV4")
//         const nftContractV4 = await upgrades.upgradeProxy(nftContract.address, fanV4) as FantiumNFTV4

//         /// ADMIN ON V1
//         // add fan address to KYC
//         await nftContractV4.connect(kycManager).addAddressToKYC(fan.address)
//         // unpause collection minting
//         await nftContractV4.connect(platformManager).toggleCollectionMintable(1)
//         // set allowlist allocation
//         await nftContractV4.connect(platformManager).batchAllowlist(1, [fan.address], [10])

//         // allocation
//         await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals * 10)

//         await nftContractV4.connect(fan).batchMint(1, 10);
//         /// 
//         expect(await nftContractV4.balanceOf(fan.address)).to.equal(10)

//         // check that tokenIds are minted
//         expect(await nftContractV4.tokenURI(1000000)).to.equal("https://contract.com/1000000")

//     })
})


