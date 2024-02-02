import { writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {

  const [deployer] = await ethers.getSigners();
  const trustedForwarder = '0xb539068872230f20456CF38EC52EF2f91AF4AE49'
  const nftContractAddress = '0x053C3a3b73831111Ddae96Fcb9726916C6b1b1C0'
  const payOutToken = '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238'

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const FantiumClaiming = await ethers.getContractFactory("FantiumClaimingV1");
  const claimingContract = await upgrades.deployProxy(FantiumClaiming, [deployer.address,payOutToken ,nftContractAddress,trustedForwarder],{ initializer: 'initialize', kind: 'uups'})
  await claimingContract.deployed();

  // vault: 0x77C0B68aD8e5f07fE7C596512496262bDa5f0598
  console.log("FantiumClaiming deployed to:", claimingContract.address);

  const data = {
    "proxy": claimingContract.address,
    "implementation": await upgrades.erc1967.getImplementationAddress(claimingContract.address),
  }
  writeFileSync(join(__dirname, './addresses/Test_claimingContract.json'), JSON.stringify(data), {
    flag: 'w',
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
