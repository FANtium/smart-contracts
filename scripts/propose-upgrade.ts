import { readFileSync } from "fs";
import { ethers, defender, upgrades } from "hardhat";

async function main() {

    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    // We get the contract to deploy
    // const contents = readFileSync(join(__dirname, './contractAddresses.json'), 'utf-8');
    // console.log(JSON.parse(contents));
    // const contractAddresses = JSON.parse(contents)

    const fantiumUpgrade = await ethers.getContractFactory("FantiumNFTV2");
    console.log("Preparing proposal...");

    const proposal = await upgrades.prepareUpgrade('0x2b98132E7cfd88C5D854d64f436372838A9BA49d', fantiumUpgrade);
    console.log("Upgrade proposal created at:", proposal);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    })