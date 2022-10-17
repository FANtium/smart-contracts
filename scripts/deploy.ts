import { writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const FantiumNFTV1 = await ethers.getContractFactory("FantiumNFTV1");
  const nftContract = await upgrades.deployProxy(FantiumNFTV1, ["FANtium", "FAN", 1], { initializer: 'initialize' })

  await nftContract.deployed();

  console.log("FantiumNFTV1 deployed to:", nftContract.address);

  const data = {
    "proxy": nftContract.address,
    "implementation": await upgrades.erc1967.getImplementationAddress(nftContract.address)
  }
  writeFileSync(join(__dirname, './address/contractAddresses.json'), JSON.stringify(data), {
    flag: 'w',
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
