import { writeFileSync } from "fs";
import { ethers } from "hardhat";
import { join } from "path";

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // We get the contract to deploy
  const FantiumNFTV1 = await ethers.getContractFactory("FantiumNFTV1");
  const nftContract = await FantiumNFTV1.deploy("FANtium", "FAN", 1);

  await nftContract.deployed();

  console.log("FantiumNFTV1 deployed to:", nftContract.address);

  const FantiumMinterFactory = await ethers.getContractFactory("FantiumMinterV1");
  const minterContract = await FantiumMinterFactory.deploy(nftContract.address);

  await minterContract.deployed();

  console.log("FantiumMinterV1 deployed to:", minterContract.address);

  const data = {
    "FantiumNFTV1": nftContract.address,
    "FantiumMinterV1": minterContract.address,
  }
  writeFileSync(join(__dirname, './address/contractAddresses.json'), JSON.stringify(data), {
    flag: 'w',
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
