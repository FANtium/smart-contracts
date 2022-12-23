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

  const data = {
    "address": mock20.address
  }
  writeFileSync(join(__dirname, './addresses/mock20.json'), JSON.stringify(data), {
    flag: 'w',
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
