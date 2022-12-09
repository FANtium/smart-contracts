import { ethers } from 'hardhat'
import { readFileSync } from 'fs';
import { join } from 'path';
import { FantiumNFTV1 } from '../typechain-types';

const primarySalePercentage = 90
const secondarySalePercentage = 5
const maxInvocations = 100
const priceInWei = 100
const earningsSplit = 10

async function main() {

    const [owner] = await ethers.getSigners();
    console.log("Account balance:", (await owner.getBalance()).toString());

    const contents = readFileSync(join(__dirname, './contractAddresses.json'), 'utf-8');
    console.log(JSON.parse(contents));
    const contractAddresses = JSON.parse(contents)

    const nftContract = await ethers.getContractAt("FantiumNFTV1", contractAddresses.nftProxy, owner) as FantiumNFTV1

    // await nftContract.grantRole(await nftContract.PLATFORM_MANAGER_ROLE(), owner.address)
    // await nftContract.grantRole(await nftContract.KYC_MANAGER_ROLE(), owner.address)

    // await nftContract.updateFantiumPrimarySaleAddress('0x0EA1ceeE6832573766790d6c1E1D297DE5136D61')
    // await nftContract.updateFantiumSecondarySaleAddress('0x0EA1ceeE6832573766790d6c1E1D297DE5136D61')
    // await nftContract.updateFantiumSecondaryMarketRoyaltyBPS(250)
    // await nftContract.updateBaseURI("https://algobits.mypinata.cloud/ipfs/QmWa6KxjWcS7krEpHEjz5n1WPBnLLaaVWiHWfior3FtVH4/")
    // await nftContract.addAddressToKYC(owner.address)
    // await nftContract.updatePaymentToken(contractAddresses.mock20)

    // // add a collection
    // await nftContract.addCollection(
    //     '0x87C9D699cabB94720Aaf0bC1416a5114fcC0D928',
    //     primarySalePercentage,
    //     secondarySalePercentage,
    //     maxInvocations,
    //     priceInWei,
    //     earningsSplit
    // )

    // await nftContract.addCollection(
    //     '0x87C9D699cabB94720Aaf0bC1416a5114fcC0D928',
    //     primarySalePercentage,
    //     secondarySalePercentage,
    //     maxInvocations,
    //     priceInWei,
    //     earningsSplit
    // )

    // await nftContract.addCollection(
    //     '0x87C9D699cabB94720Aaf0bC1416a5114fcC0D928',
    //     primarySalePercentage,
    //     secondarySalePercentage,
    //     maxInvocations,
    //     priceInWei,
    //     earningsSplit
    // )

    // await nftContract.addCollection(
    //     '0x87C9D699cabB94720Aaf0bC1416a5114fcC0D928',
    //     primarySalePercentage,
    //     secondarySalePercentage,
    //     maxInvocations,
    //     priceInWei,
    //     earningsSplit
    // )

    // await nftContract.toggleCollectionMintable(2)
    // await nftContract.toggleCollectionPaused(2)

    // mint a token

    // await nftContract.mint(
    //     1, priceInWei)
    // await nftContract.mint(
    //     1, priceInWei)

    await nftContract.mint(
        2, priceInWei)
    await nftContract.mint(
        2, priceInWei)

    // await nftContract.mint(
    //     3, priceInWei)
    // await nftContract.mint(
    //     3, priceInWei)    await nftContract.mint(
    //         3, priceInWei)
    // await nftContract.mint(
    //     3, priceInWei)

    // await nftContract.mint(
    //     4, priceInWei)
    // await nftContract.mint(
    //     4, priceInWei)
    // await nftContract.mint(
    //     4, priceInWei)
    // await nftContract.mint(
    //     4, priceInWei)


}

function sleep(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});