import { readFileSync, writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // We get the contract to deploy
  const contents = readFileSync(join(__dirname, './contractAddresses.json'), 'utf-8');
  console.log(JSON.parse(contents));
  const contractAddresses = JSON.parse(contents)

  const FantiumNFTV2 = await ethers.getContractFactory("FantiumNFTV2");
  await upgrades.validateUpgrade(contractAddresses.nftProxy, FantiumNFTV2);

  //upgrade proxy
  const nftContract = await upgrades.upgradeProxy(contractAddresses.nftProxy, FantiumNFTV2)

  const data = {
    "nftProxy": nftContract.address,
    "nftImplementation": await upgrades.erc1967.getImplementationAddress(nftContract.address),
    "mock20": contractAddresses.mock20
  }

  writeFileSync(join(__dirname, './contractAddresses.json'), JSON.stringify(data), {
    flag: 'w',
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
