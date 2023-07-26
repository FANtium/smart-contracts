import { readFileSync, writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // We get the contract to deploy
  const contents = readFileSync(join(__dirname, './addresses/claimingContract.json'), 'utf-8');
  console.log(JSON.parse(contents));
  const contractAddresses = JSON.parse(contents)

  const FantiumClaimingV1 = await ethers.getContractFactory("FantiumClaimingV1");
  await upgrades.validateUpgrade(contractAddresses.proxy, FantiumClaimingV1);

  //upgrade proxy
  const FantiumClaiming = await upgrades.upgradeProxy("0x5ec1Dda9308DeC38231F2C3d22C757ecDbcf6b20", FantiumClaimingV1)

  const data = {
    "proxy": FantiumClaiming.address,
    "implementation": await upgrades.erc1967.getImplementationAddress(FantiumClaiming.address),
  }

  writeFileSync(join(__dirname, './addresses/claimingContract.json'), JSON.stringify(data), {
    flag: 'w',
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
