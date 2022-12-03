import { ethers } from 'hardhat'
import { readFileSync } from 'fs';
import { join } from 'path';
import { FantiumNFTV1, FantiumMinterV1 } from '../typechain-types';

async function main() {

    const [owner] = await ethers.getSigners();
    console.log("Account balance:", (await owner.getBalance()).toString());

    const contents = readFileSync(join(__dirname, './contractAddresses.json'), 'utf-8');
    console.log(JSON.parse(contents));
    const contractAddresses = JSON.parse(contents)

    const nftContract = await ethers.getContractAt("FantiumNFTV1", contractAddresses.nftProxy, owner) as FantiumNFTV1
    const minterContract = await ethers.getContractAt("FantiumMinterV1", contractAddresses.minterProxy, owner) as FantiumMinterV1

    // Set the FantiumMinterV1 contract as the minter for the FantiumNFTV1 contract
    await nftContract.updateFantiumMinterAddress(minterContract.address)

    // Set the FantiumNFTV1 contract as the nft contract for the FantiumMinterV1 contract
    await minterContract.updateFantiumNFTAddress(nftContract.address)

    // Set Fantium address for primary sale
    await nftContract.updateFantiumPrimarySaleAddress('0x0EA1ceeE6832573766790d6c1E1D297DE5136D61')
    await nftContract.updateFantiumSecondarySaleAddress('0x0EA1ceeE6832573766790d6c1E1D297DE5136D61')
    await nftContract.updateFantiumSecondaryMarketRoyaltyBPS(250)

    await nftContract.updateTiers("bronze", 10, 10000, 10)
    await nftContract.updateTiers("silver", 100, 1000, 20)
    await nftContract.updateTiers("gold", 1000, 100, 30)

    // Add a collection
    await nftContract.addCollection(
        "Test Collection Name",
        "Test Athlete Name",
        "ipfs://QmdFhYU62LXSY51LSQLV2dHJwXNBNdn9nwBYkCMbkbyeSn/",
        '0x87C9D699cabB94720Aaf0bC1416a5114fcC0D928',
        90, // athlete primary sale percentage
        5, // athlete secondary sale percentage
        "silver",
    )

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});