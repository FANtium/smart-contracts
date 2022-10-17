import { ethers } from 'hardhat'
import { readFileSync } from 'fs';
import { join } from 'path';
import { FantiumNFTV1 } from '../typechain-types';

async function main() {

    let nftContract: FantiumNFTV1

    const [owner, fantium, athlete] = await ethers.getSigners();
    console.log("Account balance:", (await owner.getBalance()).toString());

    const contents = readFileSync(join(__dirname, './contractAddresses.json'), 'utf-8');
    console.log(JSON.parse(contents));
    const contractAddresses = JSON.parse(contents)

    nftContract = await ethers.getContractAt("FantiumNFTV1", contractAddresses.proxy, owner) as FantiumNFTV1

    await nftContract.updateFantiumPrimarySaleAddress(owner.address)
    await nftContract.updateFantiumSecondarySaleAddress(owner.address)
    await nftContract.updateFantiumSecondaryMarketRoyaltyBPS(250)
    await nftContract.setNextCollectionId(1)

    await nftContract.updateTiers("bronze", 10, 10000, 10)
    await nftContract.updateTiers("silver", 100, 1000, 20)
    await nftContract.updateTiers("gold", 1000, 100, 30)

    await nftContract.addCollection(
        "Collection test 1", // Collection name
        "Athlete test 1", // Athlete name
        "https://test.com/", // base URI
        "0x0000000000000000000000000000000000000000", // Athlete address
        100, // max supply
        0, // athlete primary sale percentage 0-100
        "silver", // athlete secondary sale percentage 0-100
    );

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});