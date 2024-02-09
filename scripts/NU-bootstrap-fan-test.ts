import { ethers } from 'hardhat'
import { readFileSync } from 'fs';
import { join } from 'path';
import { FantiumNFTV5_Test } from '../typechain-types';

const primarySalePercentage = 90
const secondarySalePercentage = 5
const maxInvocations = 100
const price = 1
const fantiumSecondarySalesBPS = 250
const tournamentEarningShare1e7 = 100
const otherEarningShare1e7 = 0


async function main() {

    const [owner] = await ethers.getSigners();
    console.log("Account balance:", (await owner.getBalance()).toString());

    const contents = readFileSync(join(__dirname, './addresses/Test_sepolia_fantiumNFT.json'), 'utf-8');
    console.log(JSON.parse(contents));
    const contractAddresses = JSON.parse(contents)

    const nftContract = await ethers.getContractAt("FantiumNFTV5_Test", contractAddresses.proxy, owner) as FantiumNFTV5_Test


    // await nftContract.grantRole(await nftContract.PLATFORM_MANAGER_ROLE(), owner.address)


    // add a collection

    const timestamp = Number((await ethers.provider.getBlock("latest")).timestamp + 0)

    
    for (let i = 1; i < 13; i++) {
        let tx;
        let receipt;


        // check if collection exists and create
        const exists = (await nftContract.collections(i)).exists;
        
        if (!exists) {
        let tx = await nftContract.addCollection(
            owner.address,
            primarySalePercentage,
            secondarySalePercentage,
            maxInvocations,
            price,
            timestamp,
            owner.address,
            fantiumSecondarySalesBPS,
            tournamentEarningShare1e7,
            otherEarningShare1e7
        )
        
        console.log('collection added', i)
        
        let receipt = await tx.wait();
        console.log('Transaction mined, block number:', receipt.blockNumber);
        }

        // check if collection is mintable if not make it mintable
        const mintable = (await nftContract.collections(i)).isMintable;
        if (!mintable) {
            tx = await nftContract.toggleCollectionMintable(i)
            console.log('collection mintable', i)
            receipt = await tx.wait();
            console.log('Transaction mined, block number:', receipt.blockNumber);
        }

        // check if collection is paused - if it is paused unpause it
        const paused = (await nftContract.collections(i)).isPaused;
        if (paused) {
            tx = await nftContract.toggleCollectionPaused(i)
            console.log('collection unpaused', i)
            receipt = await tx.wait();
            console.log('Transaction mined, block number:', receipt.blockNumber);
        }

        // mint a token
        tx =  await nftContract.mintTo(owner.address,i,1)
        console.log('token minted', i)
        receipt = await tx.wait();
        console.log('Transaction mined, block number:', receipt.blockNumber);
    }

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});