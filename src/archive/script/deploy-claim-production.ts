import { writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const defaultAdminAddress = "0x77C0B68aD8e5f07fE7C596512496262bDa5f0598";
    const payOutToken = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
    const fantiumNFTContract = "0x2b98132E7cfd88C5D854d64f436372838A9BA49d";
    const trustedForwarder = "0xBf175FCC7086b4f9bd59d5EAE8eA67b8f940DE0d";

    const FantiumClaiming = await ethers.getContractFactory("FantiumClaimingV1");
    const claimingContract = await upgrades.deployProxy(
        FantiumClaiming,
        [defaultAdminAddress, payOutToken, fantiumNFTContract, trustedForwarder],
        { initializer: "initialize", kind: "uups" },
    );
    await claimingContract.deployed();

    // vault: 0x77C0B68aD8e5f07fE7C596512496262bDa5f0598
    console.log("FantiumClaiming deployed to:", claimingContract.address);

    const data = {
        proxy: claimingContract.address,
        implementation: await upgrades.erc1967.getImplementationAddress(claimingContract.address),
    };
    writeFileSync(join(__dirname, "./addresses/claimingContract.json"), JSON.stringify(data), {
        flag: "w",
    });
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
