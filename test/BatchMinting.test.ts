// import { ethers, upgrades } from 'hardhat'
// import { expect } from 'chai'
// import { beforeEach } from 'mocha'
// import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
// import { FantiumNFT } from '../typechain-types/contracts/FantiumNFT'
// import { Mock20 } from '../typechain-types/contracts/Mock20'
// import { FantiumBatchMinting } from '../typechain-types'

// describe("BatchMinting", () => {

//     let nftContract: FantiumNFT
//     let erc20Contract: Mock20
//     let defaultAdmin: SignerWithAddress
//     let platformManager: SignerWithAddress
//     let kycManager: SignerWithAddress
//     let fantium: SignerWithAddress
//     let athlete: SignerWithAddress
//     let fan: SignerWithAddress
//     let other: SignerWithAddress

//     const primarySalePercentage = 9000
//     const secondarySalePercentage = 500
//     const maxInvocations = 100
//     const price = 100
//     const earningsSplit = 10
//     let timestamp = 0
//     let decimals = 18
//     let fantiumSecondaryBPS = 250

//     // scenario
//     // mint 1 or many NFTs if all conditions are met

//     beforeEach(async () => {
//         const [_defaultAdmin, _platformManager, _kycManager, _fantium, _athlete, _fan, _other] = await ethers.getSigners()
//         defaultAdmin = _defaultAdmin
//         platformManager = _platformManager
//         kycManager = _kycManager
//         fantium = _fantium
//         athlete = _athlete
//         fan = _fan
//         other = _other

//         const Mock20 = await ethers.getContractFactory("Mock20")
//         erc20Contract = await Mock20.connect(fan).deploy() as Mock20

//         const FantiumNFT = await ethers.getContractFactory("FantiumNFT")
//         nftContract = await upgrades.deployProxy(FantiumNFT, ["FANtium", "FAN", defaultAdmin.address], { initializer: 'initialize' }) as FantiumNFT

//         // set Roles
//         await nftContract.connect(defaultAdmin).grantRole(await nftContract.PLATFORM_MANAGER_ROLE(), platformManager.address)
//         await nftContract.connect(defaultAdmin).grantRole(await nftContract.KYC_MANAGER_ROLE(), kycManager.address)

//         // set payment token
//         await nftContract.connect(platformManager).updatePaymentToken(erc20Contract.address)

//         // get timestamp
//         timestamp = (await ethers.provider.getBlock("latest")).timestamp

//         // add first collection
//         await nftContract.connect(platformManager).addCollection(
//             athlete.address,
//             primarySalePercentage,
//             secondarySalePercentage,
//             maxInvocations,
//             price,
//             earningsSplit,
//             timestamp,
//             fantium.address,
//             fantiumSecondaryBPS
//         )

//         // set contract base URI
//         await nftContract.connect(platformManager).updateBaseURI("https://contract.com/")

//         // set erc20 token address
//         await nftContract.connect(platformManager).updatePaymentToken(erc20Contract.address)

//         // pause the contract
//         await nftContract.connect(platformManager).pause()

//         // unpause contract
//         await nftContract.connect(platformManager).unpause()

//         // set decoimals
//         decimals = await erc20Contract.decimals()
//     })

//     it("checks that we can deploy upgrade", async () => {
//         const fanV2 = await ethers.getContractFactory("FantiumBatchMinting")
//         const nftContractV2 = await upgrades.upgradeProxy(nftContract.address, fanV2) as FantiumBatchMinting

//         expect(await nftContractV2.name()).to.equal("FANtium")
//     })

//     it("checks that state is preserved", async () => {

//         /// MINT on V1
//         // add fan address to KYC
//         await nftContract.connect(kycManager).addAddressToKYC(fan.address)
//         // unpause collection minting
//         await nftContract.connect(platformManager).toggleCollectionPaused(1)
//         await nftContract.connect(platformManager).toggleCollectionMintable(1)
//         // check if fan can mint
//         await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals)
//         await nftContract.connect(fan).mint(1);

//         /// DEPLOY V2
//         const fanV2 = await ethers.getContractFactory("FantiumBatchMinting")
//         const nftContractV2 = await upgrades.upgradeProxy(nftContract.address, fanV2) as FantiumBatchMinting

//         /// CHECK STATE
//         expect(await nftContractV2.name()).to.equal("FANtium")
//         expect(await nftContractV2.balanceOf(fan.address)).to.equal(1)
//     })

//     it("checks that FAN can batch mint 10 NFTs if collection is Mintable and Unpaused", async () => {
//         /// DEPLOY V2
//         const fanV2 = await ethers.getContractFactory("FantiumBatchMinting")
//         const nftContractV2 = await upgrades.upgradeProxy(nftContract.address, fanV2) as FantiumBatchMinting

//         /// ADMIN ON V1
//         // add fan address to KYC
//         await nftContractV2.connect(kycManager).addAddressToKYC(fan.address)
//         // unpause collection minting
//         await nftContractV2.connect(platformManager).toggleCollectionPaused(1)
//         await nftContractV2.connect(platformManager).toggleCollectionMintable(1)
//         // check if fan can mint
//         await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals * 10)
//         await nftContractV2.connect(fan).batchMint(1, 10);

//         /// 
//         expect(await nftContractV2.balanceOf(fan.address)).to.equal(10)
//     })

//     // check that FAN can't mint if collection is not Mintable
//     it("checks that FAN can't mint if collection is not Mintable", async () => {
//         /// DEPLOY V2
//         const fanV2 = await ethers.getContractFactory("FantiumBatchMinting")
//         const nftContractV2 = await upgrades.upgradeProxy(nftContract.address, fanV2) as FantiumBatchMinting

//         /// ADMIN ON V1
//         // add fan address to KYC
//         await nftContractV2.connect(kycManager).addAddressToKYC(fan.address)
//         // unpause collection minting
//         await nftContractV2.connect(platformManager).toggleCollectionPaused(1)
//         // check if fan can mint
//         await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals)
//         await expect(nftContractV2.connect(fan).batchMint(1, 10)).to.be.revertedWith("Collection is not mintable")
//     })

//     // check that FAN can mint if collection is Mintable, Paused and has sufficient allowlist allocation
//     it("checks that FAN can mint if collection is Mintable, Paused and has sufficient allowlist allocation", async () => {
//         /// DEPLOY V2
//         const fanV2 = await ethers.getContractFactory("FantiumBatchMinting")
//         const nftContractV2 = await upgrades.upgradeProxy(nftContract.address, fanV2) as FantiumBatchMinting

//         /// ADMIN ON V1
//         // add fan address to KYC
//         await nftContractV2.connect(kycManager).addAddressToKYC(fan.address)
//         // unpause collection minting
//         await nftContractV2.connect(platformManager).toggleCollectionMintable(1)
//         // set allowlist allocation
//         await nftContractV2.connect(platformManager).increaseAllowListAllocation(1, fan.address ,10)
        
//         // allocation
//         await erc20Contract.connect(fan).approve(nftContract.address, price * 10 ** decimals * 10)
        
        
//         await nftContractV2.connect(fan).batchMint(1, 10);

//         /// 
//         expect(await nftContractV2.balanceOf(fan.address)).to.equal(10)

//         // check that tokenIds are minted
//         expect(await nftContractV2.tokenURI(1000004)).to.equal("https://contract.com/1000004")

//     })
// })

