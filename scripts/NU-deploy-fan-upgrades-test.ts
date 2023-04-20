import { readFileSync, writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // We get the contract to deploy
  const contents = readFileSync(join(__dirname, './addresses/FantiumNFT.json'), 'utf-8');
  console.log(JSON.parse(contents));
  const contractAddresses = JSON.parse(contents)

  const FantiumV3 = await ethers.getContractFactory("FantiumNFTV3");
  await upgrades.validateUpgrade(contractAddresses.proxy, FantiumV3);

  //upgrade proxy
  const nftContract = await upgrades.upgradeProxy("0x0020b7d87a663F7c113f85230f084856EE79033B", FantiumV3)

  const data = {
    "proxy": nftContract.address,
    "implementation": await upgrades.erc1967.getImplementationAddress(nftContract.address),
  }

  writeFileSync(join(__dirname, './addresses/FantiumNFT.json'), JSON.stringify(data), {
    flag: 'w',
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
