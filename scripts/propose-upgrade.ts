import { readFileSync } from "fs";
import { ethers, defender, upgrades } from "hardhat";
import { join } from "path";

async function main() {

    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    // We get the contract to deploy
    const contents = readFileSync(join(__dirname, './contractAddresses.json'), 'utf-8');
    console.log(JSON.parse(contents));
    const contractAddresses = JSON.parse(contents)

    const F2 = await ethers.getContractFactory("F2");
    console.log("Preparing proposal...");

    const proposal = await upgrades.prepareUpgrade(contractAddresses.nftProxy, F2);
    console.log("Upgrade proposal created at:", proposal);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    })