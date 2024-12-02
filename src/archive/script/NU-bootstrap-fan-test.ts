import { ethers } from "hardhat";
import { readFileSync } from "fs";
import { join } from "path";
import { FantiumNFT } from "../typechain-types";

const primarySalePercentage = 90;
const secondarySalePercentage = 5;
const maxInvocations = 100;
const price = 1;
const earningsSplit = 10;

async function main() {
    const [owner] = await ethers.getSigners();
    console.log("Account balance:", (await owner.getBalance()).toString());

    const contents = readFileSync(join(__dirname, "./addresses/fantium.json"), "utf-8");
    console.log(JSON.parse(contents));
    const contractAddresses = JSON.parse(contents);

    const nftContract = (await ethers.getContractAt("FantiumNFT", contractAddresses.proxy, owner)) as FantiumNFT;

    const mock20Address = readFileSync(join(__dirname, "./addresses/mock20.json"), "utf-8");
    console.log(JSON.parse(mock20Address));
    const mock20Addresses = JSON.parse(mock20Address);

    // const mock20Contract = await ethers.getContractAt("Mock20", mock20Addresses.address, owner)
    // await mock20Contract.approve(nftContract.address, price * 10 ** 6)

    // await nftContract.grantRole(await nftContract.PLATFORM_MANAGER_ROLE(), owner.address)
    // await nftContract.grantRole(await nftContract.KYC_MANAGER_ROLE(), owner.address)

    // CONTRACT PARAMS
    // await nftContract.updateBaseURI("https://algobits.mypinata.cloud/ipfs/QmWa6KxjWcS7krEpHEjz5n1WPBnLLaaVWiHWfior3FtVH4/")
    // await nftContract.addAddressToKYC(owner.address)

    //KYC addresses
    // await nftContract.updatePaymentToken("0x1946FB4C65d9036a9526cf20265382a1dCC6C652")

    // // add a collection
    // const timestamp = (await ethers.provider.getBlock("latest")).timestamp + 0

    // await nftContract.addCollection(
    //     '0x87C9D699cabB94720Aaf0bC1416a5114fcC0D928',
    //     primarySalePercentage,
    //     secondarySalePercentage,
    //     maxInvocations,
    //     price,
    //     earningsSplit,
    //     timestamp,
    //     owner.address,
    //     250
    // )

    // await nftContract.toggleCollectionMintable(1)
    // await nftContract.toggleCollectionPaused(1)

    // mint a token
    await nftContract.mint(1);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
