import { writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const FantiumUserManager = await ethers.getContractFactory("FantiumUserManager");
    const userManagerContract = await upgrades.deployProxy(
        FantiumUserManager,
        [
            deployer.address,
            "0x0020b7d87a663F7c113f85230f084856EE79033B",
            "0x3De3D4eaC11c6468140Ffd661C009D52c4956F55",
            "0xBf175FCC7086b4f9bd59d5EAE8eA67b8f940DE0d",
        ],
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
