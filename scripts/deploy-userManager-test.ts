import { writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {

  const [deployer] = await ethers.getSigners();

  const trustedForwarder = '0xb539068872230f20456CF38EC52EF2f91AF4AE49'
  const nftContractAddress = '0x053C3a3b73831111Ddae96Fcb9726916C6b1b1C0'
  const claimingContractAddress = '0x23B1cc7f5B7560c202750C076e3E7567DCF4c033'

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const FantiumUserManager = await ethers.getContractFactory("FantiumUserManager");
  const userManagerContract = await upgrades.deployProxy(FantiumUserManager, [deployer.address, nftContractAddress, claimingContractAddress, trustedForwarder], { initializer: 'initialize', kind: 'uups'})
  await userManagerContract.deployed();

  // vault: 0x77C0B68aD8e5f07fE7C596512496262bDa5f0598
  console.log("FantiumUserManager deployed to:", userManagerContract.address);

  const data = {
    "proxy": userManagerContract.address,
    "implementation": await upgrades.erc1967.getImplementationAddress(userManagerContract.address),
  }
  writeFileSync(join(__dirname, './addresses/userManager.json'), JSON.stringify(data), {
    flag: 'w',
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
