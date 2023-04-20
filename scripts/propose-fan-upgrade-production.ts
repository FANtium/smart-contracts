import { ethers, upgrades } from "hardhat";

async function main() {

    const upgradeContractName = "FantiumNFTV3";
    const proxyContractAddress = "0x2b98132E7cfd88C5D854d64f436372838A9BA49d";

    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const fantiumUpgrade = await ethers.getContractFactory(upgradeContractName);
    console.log("Preparing proposal...");

    const proposal = await upgrades.prepareUpgrade(proxyContractAddress, fantiumUpgrade);
    console.log("Upgrade proposal created at:", proposal);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    })
    