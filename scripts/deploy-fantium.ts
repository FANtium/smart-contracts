import { writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const FantiumNFTV1 = await ethers.getContractFactory("FantiumNFT");
  const fanContract = await upgrades.deployProxy(FantiumNFTV1, ["FANtium", "FAN", deployer.address], { initializer: 'initialize', kind: 'uups'})
  await fanContract.deployed();

  console.log("FantiumNFTV1 deployed to:", fanContract.address);

  const data = {
    "proxy": fanContract.address,
    "implementation": await upgrades.erc1967.getImplementationAddress(fanContract.address),
  }
  writeFileSync(join(__dirname, './addresses/fantium.json'), JSON.stringify(data), {
    flag: 'w',
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
