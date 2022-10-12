import { readFileSync, writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // We get the contract to deploy
  const contents = readFileSync(join(__dirname, './address/contractAddresses.json'), 'utf-8');
  console.log(JSON.parse(contents));
  const contractAddresses = JSON.parse(contents)

  const FantiumMinterFactory = await ethers.getContractFactory("FantiumMinterV2");
  const minterContract = await upgrades.upgradeProxy(contractAddresses.minterProxyContract, FantiumMinterFactory);

  console.log("FantiumMinterV1 deployed to:", minterContract.address);

  const data = {
    "FantiumNFTV1": contractAddresses.FantiumNFTV1,
    "minterProxyContract": contractAddresses.minterProxyContract,
    "minterImplementation": await upgrades.erc1967.getImplementationAddress(contractAddresses.minterProxyContract)
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
