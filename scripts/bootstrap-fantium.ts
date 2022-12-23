import { ethers } from 'hardhat'
import { readFileSync } from 'fs';
import { join } from 'path';
import { FantiumNFT } from '../typechain-types';

const primarySalePercentage = 90
const secondarySalePercentage = 5
const maxInvocations = 100
const price = 1
const earningsSplit = 10

async function main() {

    const [owner] = await ethers.getSigners();
    console.log("Account balance:", (await owner.getBalance()).toString());

    const contents = readFileSync(join(__dirname, './addresses/fantium.json'), 'utf-8');
    console.log(JSON.parse(contents));
    const contractAddresses = JSON.parse(contents)

    const nftContract = await ethers.getContractAt("FantiumNFT", contractAddresses.proxy, owner) as FantiumNFT

    // await nftContract.grantRole(await nftContract.PLATFORM_MANAGER_ROLE(), owner.address)
    // await nftContract.grantRole(await nftContract.KYC_MANAGER_ROLE(), owner.address)

    // CONTRACT PARAMS
    // await nftContract.updateFantiumPrimarySaleAddress('0x0EA1ceeE6832573766790d6c1E1D297DE5136D61')
    // await nftContract.updateFantiumSecondarySaleAddress('0x0EA1ceeE6832573766790d6c1E1D297DE5136D61')
    // await nftContract.updateFantiumSecondaryMarketRoyaltyBPS(250)
    // await nftContract.updateBaseURI("https://algobits.mypinata.cloud/ipfs/QmWa6KxjWcS7krEpHEjz5n1WPBnLLaaVWiHWfior3FtVH4/")
    // await nftContract.addAddressToKYC(owner.address)

    //KYC addresses
    // await nftContract.addAddressToKYC("0x11ffec775ac3a3ac6366341a1e4d0738b408d4f0")
    // await nftContract.addAddressToKYC("0xF92Df69eCCc0C8D1fb7c257F9fd133B8c3431233")
    // await nftContract.addAddressToKYC("0x1e905c32A4b44662Ef86BCd5e633790846C396e4")
    // await nftContract.addAddressToKYC("0x9acf11c4cd68d53596fd24699673485de24c025a")
    // await nftContract.addAddressToKYC("0x39Dc7260694503cbeDB08FF838365Bd94d2422f4")
    // await nftContract.addAddressToKYC("0xb8bc655b69a848A2C7173180CD54A11A03b64493")
    // await nftContract.updatePaymentToken("0xE09A37dF3fB8017F5f50dbF43FBEa619c5b9532f")

    // await nftContract.updateCollectionTier(2, 100, 1, 10)
    // add a collection
    // const timestamp = (await ethers.provider.getBlock("latest")).timestamp + 0

    // await nftContract.addCollection(
    //     '0x87C9D699cabB94720Aaf0bC1416a5114fcC0D928',
    //     primarySalePercentage,
    //     secondarySalePercentage,
    //     maxInvocations,
    //     price,
    //     earningsSplit,
    //     timestamp
    // )

    // await nftContract.addCollection(
    //     '0x87C9D699cabB94720Aaf0bC1416a5114fcC0D928',
    //     primarySalePercentage,
    //     secondarySalePercentage,
    //     maxInvocations,
    //     price,
    //     earningsSplit,
    //     timestamp
    // )

    // await nftContract.toggleCollectionMintable(1)
    // await nftContract.toggleCollectionPaused(1)

    // await nftContract.toggleCollectionMintable(2)
    // await nftContract.toggleCollectionPaused(2)

    // mint a token

    // await nftContract.mint(
    //     1)
    // await nftContract.mint(
    //     1, priceInWei)


}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});