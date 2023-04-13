import { writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const MockUSDC = await ethers.getContractFactory("MockUSDC");
  const mockTokens = await MockUSDC.deploy("MockUSDC", "USDC", 6)
  await mockTokens.deployed();

  // vault: 0x77C0B68aD8e5f07fE7C596512496262bDa5f0598
  console.log("FantiumNFT deployed to:", mockTokens.address);

  const data = {
    "Address": mockTokens.address,
  }
  writeFileSync(join(__dirname, './addresses/MockUSDC.json'), JSON.stringify(data), {
    flag: 'w',
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
