import { readFileSync, writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // We get the contract to deploy
  const contents = readFileSync(join(__dirname, './addresses/Test_sepolia_fantiumNFT.json'), 'utf-8');
  console.log(JSON.parse(contents));
  const contractAddresses = JSON.parse(contents)

  //validate upgrade
  console.log('validating upgrade...');
  const FantiumV5_Test = await ethers.getContractFactory("FantiumNFTV5_Test");
  await upgrades.validateUpgrade(contractAddresses.proxy, FantiumV5_Test);

  //upgrade proxy
  console.log('Upgrading...');
  const nftContract = await upgrades.upgradeProxy(contractAddresses.proxy, FantiumV5_Test)

  const data = {
    "proxy": nftContract.address,
    "implementation": await upgrades.erc1967.getImplementationAddress(nftContract.address),
  }

  console.log('deployment', data);

  writeFileSync(join(__dirname, './addresses/Test_sepolia_fantiumNFT.json'), JSON.stringify(data), {
    flag: 'w',
  });

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
