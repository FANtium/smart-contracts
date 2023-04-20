import { writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const FantiumClaiming = await ethers.getContractFactory("FantiumClaimingV1");
  const claimingContract = await upgrades.deployProxy(FantiumClaiming, [deployer.address,'0x53d7E299116CA5e686EBC5D9b86596fdbfc73BDb','0x0020b7d87a663F7c113f85230f084856EE79033B','0xBf175FCC7086b4f9bd59d5EAE8eA67b8f940DE0d'],{ initializer: 'initialize', kind: 'uups'})
  await claimingContract.deployed();

  // vault: 0x77C0B68aD8e5f07fE7C596512496262bDa5f0598
  console.log("FantiumClaiming deployed to:", claimingContract.address);

  const data = {
    "proxy": claimingContract.address,
    "implementation": await upgrades.erc1967.getImplementationAddress(claimingContract.address),
  }
  writeFileSync(join(__dirname, './addresses/claimingContract.json'), JSON.stringify(data), {
    flag: 'w',
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
