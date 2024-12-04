import { writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const nftContractAddress = "0x2b98132E7cfd88C5D854d64f436372838A9BA49d";
    const claimingContract = "0x534db6CE612486F179ef821a57ee93F44718a002";
    const defaultAdminAddress = "0x77C0B68aD8e5f07fE7C596512496262bDa5f0598";
    const forwarder = "0xBf175FCC7086b4f9bd59d5EAE8eA67b8f940DE0d";

    const FantiumUserManager = await ethers.getContractFactory("FantiumUserManager");
    const userManagerContract = await upgrades.deployProxy(
        FantiumUserManager,
        [defaultAdminAddress, nftContractAddress, claimingContract, forwarder],
        { initializer: "initialize", kind: "uups" },
    );
    await userManagerContract.deployed();

    // vault: 0x77C0B68aD8e5f07fE7C596512496262bDa5f0598
    console.log("FantiumUserManager deployed to:", userManagerContract.address);

    const data = {
        proxy: userManagerContract.address,
        implementation: await upgrades.erc1967.getImplementationAddress(userManagerContract.address),
    };
    writeFileSync(join(__dirname, "./addresses/userManager.json"), JSON.stringify(data), {
        flag: "w",
    });
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
