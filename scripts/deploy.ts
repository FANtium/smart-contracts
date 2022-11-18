import { writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const FantiumNFTV1 = await ethers.getContractFactory("FantiumNFTV1");
  const nftContract = await upgrades.deployProxy(FantiumNFTV1, ["FANtium", "FAN"], { initializer: 'initialize', kind: 'uups' })
  await nftContract.deployed();

  const FantiumMinterV1 = await ethers.getContractFactory("FantiumMinterV1");
  const minterContract = await upgrades.deployProxy(FantiumMinterV1, [], { initializer: 'initialize', kind: 'uups' })
  await minterContract.deployed();

  // Set the FantiumMinterV1 contract as the minter for the FantiumNFTV1 contract
  await nftContract.updateFantiumMinterAddress(minterContract.address)

  // Set the FantiumNFTV1 contract as the nft contract for the FantiumMinterV1 contract
  await minterContract.updateFantiumNFTAddress(nftContract.address)

  console.log("FantiumNFTV1 deployed to:", nftContract.address);

  const data = {
    "nft-proxy": nftContract.address,
    "nft-implementation": await upgrades.erc1967.getImplementationAddress(nftContract.address),
    "minter-proxy": minterContract.address,
    "minter-implementation": await upgrades.erc1967.getImplementationAddress(minterContract.address)
  }
  writeFileSync(join(__dirname, './contractAddresses.json'), JSON.stringify(data), {
    flag: 'w',
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
