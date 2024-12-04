import { readFileSync, writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    // We get the contract to deploy
    const contents = readFileSync(join(__dirname, "./addresses/userManager.json"), "utf-8");
    console.log(JSON.parse(contents));
    const contractAddresses = JSON.parse(contents);

    const FantiumUserManager = await ethers.getContractFactory("FantiumUserManager");
    await upgrades.validateUpgrade(contractAddresses.proxy, FantiumUserManager);

    //upgrade proxy
    const userManagerContract = await upgrades.upgradeProxy(
        "0x6034BBADa64de5F51D971C48c752CC0051F38E1E",
        FantiumUserManager,
    );

    const data = {
        proxy: userManagerContract.address,
        implementation: await upgrades.erc1967.getImplementationAddress(userManagerContract.address),
    };

    writeFileSync(join(__dirname, "./addresses/userManager.json"), JSON.stringify(data), {
        flag: "w",
    });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
