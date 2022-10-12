import { writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const FantiumNFTV1 = await ethers.getContractFactory("FantiumNFTV1");
  const nftContract = await FantiumNFTV1.deploy("FANtium", "FAN", 1);

  await nftContract.deployed();

  console.log("FantiumNFTV1 deployed to:", nftContract.address);

  const FantiumMinterFactory = await ethers.getContractFactory("FantiumMinterV1")
  const minterProxyContract = await upgrades.deployProxy(FantiumMinterFactory, [nftContract.address], { initializer: 'initialize' })
  console.log("Minter proxy address: ", minterProxyContract.address)

  await minterProxyContract.deployed();

  console.log("FantiumMinterV1 deployed to:", minterProxyContract.address);

  const data = {
    "FantiumNFTV1": nftContract.address,
    "minterProxyContract": minterProxyContract.address,
  }
  writeFileSync(join(__dirname, './address/contractAddresses.json'), JSON.stringify(data), {
    flag: 'w',
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
