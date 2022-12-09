import { writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Mock20 = await ethers.getContractFactory("Mock20");
  const mock20 = await Mock20.deploy();
  await mock20.deployed();

  const FantiumNFTV1 = await ethers.getContractFactory("FantiumNFTV1");
  const nftContract = await upgrades.deployProxy(FantiumNFTV1, ["FANtium", "FAN", deployer.address], { initializer: 'initialize', kind: 'uups'})
  await nftContract.deployed();

  console.log("FantiumNFTV1 deployed to:", nftContract.address);

  const data = {
    "nftProxy": nftContract.address,
    "nftImplementation": await upgrades.erc1967.getImplementationAddress(nftContract.address),
    "mock20": mock20.address
  }
  writeFileSync(join(__dirname, './contractAddresses.json'), JSON.stringify(data), {
    flag: 'w',
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
