import { ethers } from 'hardhat'
import { readFileSync } from 'fs';
import { join } from 'path';
import { FantiumNFTV1, FantiumMinterV1 } from '../typechain-types';

async function main() {

    let nftContract: FantiumNFTV1
    let minterContract: FantiumMinterV1

    const [owner] = await ethers.getSigners();
    console.log("Account balance:", (await owner.getBalance()).toString());

    const contents = readFileSync(join(__dirname, './address/contractAddresses.json'), 'utf-8');
    console.log(JSON.parse(contents));
    const contractAddresses = JSON.parse(contents)

    nftContract = await ethers.getContractAt("FantiumNFTV1", contractAddresses.FantiumNFTV1, owner) as FantiumNFTV1
    minterContract = await ethers.getContractAt("FantiumMinterV1", contractAddresses.FantiumMinterV1, owner) as FantiumMinterV1

    await nftContract.updateMinterContract(minterContract.address);

    await nftContract.addCollection(
        "Collection test 1", // Collection name
        "Athlete test 1", // Athlete name
        "https://test.com/", // base URI
        "0x0000000000000000000000000000000000000000", // Athlete address
        100, // max supply
        0, // price in wei
        0, // athlete primary sale percentage 0-100
        0, // athlete secondary sale percentage 0-100
    );

    await nftContract.toggleCollectionIsPaused(1);

    await minterContract.addAddressToKYC(owner.address);

    await minterContract.purchaseTo(owner.address, 1)

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});