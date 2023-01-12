import { readFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";
import { FantiumNFTV1 } from "../typechain-types";

// scripts/transfer-ownership.js
async function main () {
    const gnosisSafe = '0x218ADb5DCAE3E9881144Eeb99151E389E44435D3';
  
    console.log('Transferring ownership of ProxyAdmin...');
    // The owner of the ProxyAdmin can upgrade our contracts

    const [owner] = await ethers.getSigners();
    console.log("Account balance:", (await owner.getBalance()).toString());

    const contents = readFileSync(join(__dirname, './contractAddresses.json'), 'utf-8');
    console.log(JSON.parse(contents));
    const contractAddresses = JSON.parse(contents)
    
    
    const nftContract = await ethers.getContractAt("FantiumNFTV1", contractAddresses.nftProxy, owner) as FantiumNFTV1
    await nftContract.grantRole(await nftContract.UPGRADER_ROLE(), gnosisSafe)
    
    console.log('Transferred ownership of ProxyAdmin to:', gnosisSafe);
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });