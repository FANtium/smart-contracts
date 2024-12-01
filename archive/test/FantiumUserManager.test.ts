import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { beforeEach } from "mocha";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { FantiumNFTV2 } from "../typechain-types/contracts/FantiumNFTV2";
import { FantiumNFTV3 } from "../typechain-types/contracts/FantiumNFTV3";
import { FantiumClaimingV1 } from "../typechain-types/contracts/claiming/FantiumClaimingV1";
import { FantiumUserManager } from "../typechain-types/contracts/utils/FantiumUserManager";
import { Mock20 } from "../typechain-types/contracts/mocks/Mock20";
import { mine } from "@nomicfoundation/hardhat-network-helpers";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { start } from "repl";

describe("FantiumUserManager", () => {
    let nftContract: FantiumNFTV2;
    let nftContractV3: FantiumNFTV3;
    let claimContract: FantiumClaimingV1;
    let userManager: FantiumUserManager;
    let erc20Contract: Mock20;
    let defaultAdmin: SignerWithAddress;
    let platformManager: SignerWithAddress;
    let kycManager: SignerWithAddress;
    let fantium: SignerWithAddress;
    let athlete: SignerWithAddress;
    let fan: SignerWithAddress;
    let other: SignerWithAddress;
    let forwarder: SignerWithAddress;

    const primarySalePercentage = 9000;
    const secondarySalePercentage = 500;
    const maxInvocations = 11;
    const price = 1;
    const tournamentEarningsShare1e7 = 100000; // 0.1%
    const tournamentEarnings = 500000000000; // in 500,000 USDC without decimals
    const tournamentTokenShareBPS = 1000; // 10%
    const otherEarningsShare1e7 = 100000; // 0.1%
    const otherEarnings = 500000000000; // in 50,000 USDC without decimals
    const otherTokenShareBPS = 1000; // 10%
    const totalAmount = tournamentEarnings + otherEarnings;
    const nullAddress = "0x0000000000000000000000000000000000000000";
    let timestamp = 1;
    let startTime = 1;
    let closeTime = 1876044473;
    let decimals = 6;
    let fantiumSecondaryBPS = 250;
    let fantiumFeePBS = 250;

    beforeEach(async () => {
        const [_defaultAdmin, _platformManager, _kycManager, _fantium, _athlete, _fan, _other, _forwarder] =
            await ethers.getSigners();
        defaultAdmin = _defaultAdmin;
        platformManager = _platformManager;
        kycManager = _kycManager;
        fantium = _fantium;
        athlete = _athlete;
        fan = _fan;
        other = _other;
        forwarder = _forwarder;

        const Mock20 = await ethers.getContractFactory("Mock20");
        erc20Contract = (await Mock20.connect(fan).deploy()) as Mock20;
        await erc20Contract.connect(fan).transfer(defaultAdmin.address, 1000000 * 10 ** decimals);
        await erc20Contract.connect(fan).transfer(athlete.address, 1000000 * 10 ** decimals);
        await erc20Contract.connect(fan).transfer(platformManager.address, 1000000 * 10 ** decimals);
        await erc20Contract.connect(fan).transfer(fantium.address, 1000000 * 10 ** decimals);
        await erc20Contract.connect(fan).transfer(kycManager.address, 1000000 * 10 ** decimals);
        await erc20Contract.connect(fan).transfer(other.address, price * 10 * 10 ** decimals);

        /*//////////////////////////////////////////////////////////////
                            SETUP NFT CONTRACT
        //////////////////////////////////////////////////////////////*/

        const FantiumNFTV2 = await ethers.getContractFactory("FantiumNFTV2");
        nftContract = (await upgrades.deployProxy(FantiumNFTV2, ["FANtium", "FAN", defaultAdmin.address], {
            initializer: "initialize",
        })) as FantiumNFTV2;

        // set Roles
        await nftContract
            .connect(defaultAdmin)
            .grantRole(await nftContract.PLATFORM_MANAGER_ROLE(), platformManager.address);
        await nftContract.connect(defaultAdmin).grantRole(await nftContract.UPGRADER_ROLE(), platformManager.address);
        await nftContract.connect(defaultAdmin).grantRole(await nftContract.KYC_MANAGER_ROLE(), kycManager.address);
        // set payment token
        await nftContract.connect(platformManager).updatePaymentToken(erc20Contract.address);
        // get timestamp
        timestamp = (await ethers.provider.getBlock("latest")).timestamp;

        // set contract base URI
        await nftContract.connect(platformManager).updateBaseURI("https://contract.com/");
        // set erc20 token address
        await nftContract.connect(platformManager).updatePaymentToken(erc20Contract.address);

        // set decimals
        decimals = await erc20Contract.decimals();

        // add first collection

        for (let i = 0; i < 4; i++) {
            await nftContract
                .connect(platformManager)
                .addCollection(
                    athlete.address,
                    primarySalePercentage,
                    secondarySalePercentage,
                    maxInvocations,
                    price,
                    timestamp,
                    fantium.address,
                    fantiumSecondaryBPS,
                    tournamentEarningsShare1e7,
                );
        }

        // toggle and unpause collection mintable
        await nftContract.connect(platformManager).toggleCollectionMintable(1);
        await nftContract.connect(platformManager).toggleCollectionPaused(1);

        /*//////////////////////////////////////////////////////////////
                        SETUP CLAIMING CONTRACT
        //////////////////////////////////////////////////////////////*/

        const FantiumClaimingV1 = await ethers.getContractFactory("FantiumClaimingV1");
        claimContract = (await upgrades.deployProxy(
            FantiumClaimingV1,
            [defaultAdmin.address, erc20Contract.address, nftContract.address, forwarder.address],
            { initializer: "initialize" },
        )) as FantiumClaimingV1;
        // set Role
        await claimContract
            .connect(defaultAdmin)
            .grantRole(await claimContract.PLATFORM_MANAGER_ROLE(), platformManager.address);
        // pause the contract
        await claimContract.connect(platformManager).pause();
        // unpause contract
        await claimContract.connect(platformManager).unpause();

        /*//////////////////////////////////////////////////////////////
                        SETUP USER MANAGER CONTRACT
        //////////////////////////////////////////////////////////////*/

        const FantiumUserManager = await ethers.getContractFactory("FantiumUserManager");
        userManager = (await upgrades.deployProxy(FantiumUserManager, [
            defaultAdmin.address,
            nftContract.address,
            claimContract.address,
            forwarder.address,
        ])) as FantiumUserManager;
        //set Role and
        await userManager
            .connect(defaultAdmin)
            .grantRole(await userManager.PLATFORM_MANAGER_ROLE(), platformManager.address);
        await userManager.connect(defaultAdmin).grantRole(await userManager.UPGRADER_ROLE(), platformManager.address);
        await userManager
            .connect(defaultAdmin)
            .grantRole(await userManager.PLATFORM_MANAGER_ROLE(), kycManager.address);
        await userManager.connect(platformManager).addAllowedConctract(nftContract.address);
        await userManager.connect(platformManager).addAllowedConctract(claimContract.address);
        await claimContract.connect(platformManager).updateFantiumUserManager(userManager.address);
    });

    //////////////////////////////////////////

    it("Check: test initilizer and upgradability", async () => {
        await expect(
            userManager
                .connect(platformManager)
                .initialize(defaultAdmin.address, nftContract.address, claimContract.address, forwarder.address),
        ).to.revertedWith("Initializable: contract is already initialized");
        const FantiumUserManager = await ethers.getContractFactory("FantiumUserManager");
        userManager = (await upgrades.upgradeProxy(userManager.address, FantiumUserManager)) as FantiumUserManager;
    });

    it("Check: setup and contract allowing", async () => {
        expect(await userManager.connect(platformManager).allowedContracts(nftContract.address)).to.be.true;
        expect(await userManager.connect(platformManager).allowedContracts(claimContract.address)).to.be.true;
        expect(await userManager.connect(platformManager).allowedContracts(fan.address)).to.be.false;

        await userManager.connect(platformManager).addAllowedConctract(fan.address);
        expect(await userManager.connect(platformManager).allowedContracts(fan.address)).to.be.true;

        await userManager.connect(platformManager).removeAllowedConctract(fan.address);
        expect(await userManager.connect(platformManager).allowedContracts(fan.address)).to.be.false;

        await expect(userManager.connect(platformManager).addAllowedConctract(nullAddress)).to.revertedWith(
            "No null address allowed",
        );
        await expect(userManager.connect(platformManager).removeAllowedConctract(nullAddress)).to.revertedWith(
            "No null address allowed",
        );
    });

    it("Check: add to KYC and remove", async () => {
        await userManager
            .connect(platformManager)
            .addBatchtoKYC([fan.address, fantium.address, athlete.address, other.address]);
        await userManager.connect(platformManager).addAddressToKYC(forwarder.address);

        expect(await userManager.connect(fan).isAddressKYCed(fan.address)).to.be.true;
        expect(await userManager.connect(fantium).isAddressKYCed(fantium.address)).to.be.true;
        expect(await userManager.connect(athlete).isAddressKYCed(athlete.address)).to.be.true;
        expect(await userManager.connect(other).isAddressKYCed(other.address)).to.be.true;
        expect(await userManager.connect(forwarder).isAddressKYCed(forwarder.address)).to.be.true;
        expect(await userManager.connect(other).isAddressKYCed(forwarder.address)).to.be.true;
        expect(await userManager.connect(other).isAddressKYCed(userManager.address)).to.be.false;

        await userManager.connect(platformManager).removeAddressFromKYC(forwarder.address);
        await userManager.connect(platformManager).removeAddressFromKYC(other.address);
        await userManager.connect(platformManager).removeAddressFromKYC(athlete.address);
        await userManager.connect(platformManager).removeAddressFromKYC(athlete.address);

        expect(await userManager.connect(fan).isAddressKYCed(fan.address)).to.be.true;
        expect(await userManager.connect(fantium).isAddressKYCed(fantium.address)).to.be.true;
        expect(await userManager.connect(athlete).isAddressKYCed(athlete.address)).to.be.false;
        expect(await userManager.connect(other).isAddressKYCed(other.address)).to.be.false;
        expect(await userManager.connect(forwarder).isAddressKYCed(forwarder.address)).to.be.false;
        expect(await userManager.connect(other).isAddressKYCed(forwarder.address)).to.be.false;
    });

    it("Check: add to and remove from IDENT", async () => {
        await userManager
            .connect(platformManager)
            .addBatchtoIDENT([fan.address, fantium.address, athlete.address, other.address]);
        await userManager.connect(platformManager).addAddressToIDENT(forwarder.address);

        expect(await userManager.connect(fan).isAddressIDENT(fan.address)).to.be.true;
        expect(await userManager.connect(fantium).isAddressIDENT(fantium.address)).to.be.true;
        expect(await userManager.connect(athlete).isAddressIDENT(athlete.address)).to.be.true;
        expect(await userManager.connect(other).isAddressIDENT(other.address)).to.be.true;
        expect(await userManager.connect(forwarder).isAddressIDENT(forwarder.address)).to.be.true;
        expect(await userManager.connect(other).isAddressIDENT(forwarder.address)).to.be.true;
        expect(await userManager.connect(other).isAddressIDENT(userManager.address)).to.be.false;

        await userManager.connect(platformManager).removeAddressFromIDENT(forwarder.address);
        await userManager.connect(platformManager).removeAddressFromIDENT(other.address);
        await userManager.connect(platformManager).removeAddressFromIDENT(athlete.address);
        await userManager.connect(platformManager).removeAddressFromIDENT(athlete.address);

        expect(await userManager.connect(fan).isAddressIDENT(fan.address)).to.be.true;
        expect(await userManager.connect(fantium).isAddressIDENT(fantium.address)).to.be.true;
        expect(await userManager.connect(athlete).isAddressIDENT(athlete.address)).to.be.false;
        expect(await userManager.connect(other).isAddressIDENT(other.address)).to.be.false;
        expect(await userManager.connect(forwarder).isAddressIDENT(forwarder.address)).to.be.false;
        expect(await userManager.connect(other).isAddressIDENT(forwarder.address)).to.be.false;

        await expect(userManager.connect(fan).addAddressToIDENT(fan.address)).to.be.revertedWith("Only managers");
    });

    it("Check: add to and remove from allowlist", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3");
        const nftContractV3 = (await upgrades.upgradeProxy(nftContract.address, fanV3)) as FantiumNFTV3;

        await userManager
            .connect(platformManager)
            .batchAllowlist(
                [1],
                nftContract.address,
                [fan.address, fantium.address, athlete.address, other.address],
                [1, 1, 1, 1],
            );

        expect(await userManager.connect(fan).hasAllowlist(nftContract.address, 1, fan.address)).to.equal(1);
        expect(await userManager.connect(fantium).hasAllowlist(nftContract.address, 1, fantium.address)).to.equal(1);
        expect(await userManager.connect(athlete).hasAllowlist(nftContract.address, 1, athlete.address)).to.equal(1);
        expect(await userManager.connect(other).hasAllowlist(nftContract.address, 1, other.address)).to.equal(1);
        expect(await userManager.connect(other).hasAllowlist(nftContract.address, 1, forwarder.address)).to.equal(0);
        expect(await userManager.connect(other).hasAllowlist(nftContract.address, 2, athlete.address)).to.equal(0);
        expect(await userManager.connect(other).hasAllowlist(nftContract.address, 11, fantium.address)).to.equal(0);

        await userManager.connect(platformManager).reduceAllowListAllocation([1], nftContract.address, fan.address, 1);
        expect(await userManager.connect(fan).hasAllowlist(nftContract.address, 1, fan.address)).to.equal(0);
        expect(await userManager.connect(fantium).hasAllowlist(nftContract.address, 1, fantium.address)).to.equal(1);
        expect(await userManager.connect(fantium).hasAllowlist(nftContract.address, 3, fan.address)).to.equal(0);

        await userManager.connect(platformManager).reduceAllowListAllocation([1], nftContract.address, fan.address, 1);
        expect(await userManager.connect(fan).hasAllowlist(nftContract.address, 1, fan.address)).to.equal(0);
    });

    it("Check: only manager role can call functions", async () => {
        await expect(userManager.connect(fan).addAddressToKYC(fan.address)).to.be.revertedWith("Only managers");
        await expect(userManager.connect(fan).addAddressToIDENT(fan.address)).to.be.revertedWith("Only managers");
        await expect(userManager.connect(fan).removeAddressFromIDENT(fan.address)).to.be.revertedWith("Only managers");
        await expect(userManager.connect(fan).removeAddressFromKYC(fan.address)).to.be.revertedWith("Only managers");
        await expect(userManager.connect(fan).batchAllowlist([1], fan.address, [fan.address], [1])).to.be.revertedWith(
            "Only managers",
        );
        await expect(
            userManager.connect(fan).reduceAllowListAllocation(1, fan.address, fan.address, 1),
        ).to.be.revertedWith("Only manager or allowed Contract");
    });

    it("Check: only allowed contracts and existing collections", async () => {
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3");
        const nftContractV3 = (await upgrades.upgradeProxy(nftContract.address, fanV3)) as FantiumNFTV3;

        await expect(
            userManager.connect(platformManager).batchAllowlist([1], fan.address, [fan.address], [1]),
        ).to.be.revertedWith("Only allowed Contract");
        await expect(
            userManager.connect(platformManager).reduceAllowListAllocation(1, nftContract.address, fan.address, 1),
        );
        await expect(
            userManager.connect(platformManager).reduceAllowListAllocation(1, fan.address, fan.address, 1),
        ).to.be.revertedWith("Only allowed Contract");

        await expect(
            userManager.connect(platformManager).batchAllowlist([10], nftContract.address, [fan.address], [1]),
        ).to.be.revertedWith("Collection does not exist");
        await expect(
            userManager.connect(platformManager).reduceAllowListAllocation([10], nftContract.address, fan.address, 1),
        ).to.be.revertedWith("Collection does not exist");
    });

    it("Check: pause/unpuase", async () => {
        await userManager.connect(platformManager).pause();
        await expect(userManager.connect(fan).addAddressToKYC(fan.address)).to.be.revertedWith("Pausable: paused");
        await expect(userManager.connect(fan).addAddressToIDENT(fan.address)).to.be.revertedWith("Pausable: paused");
        await expect(
            userManager.connect(fan).batchAllowlist([1], nftContract.address, [fan.address], [1]),
        ).to.be.revertedWith("Pausable: paused");
    });

    // //////// BATCH ALLOWLISTING

    it("Check UserManager Contract: batch allowlist 100 addresses with allocations", async () => {
        /// DEPLOY V2
        const fanV3 = await ethers.getContractFactory("FantiumNFTV3");
        const nftContractV3 = (await upgrades.upgradeProxy(nftContract.address, fanV3)) as FantiumNFTV3;
        await nftContractV3
            .connect(platformManager)
            .updatePlatformAddressesConfigs(
                erc20Contract.address,
                claimContract.address,
                userManager.address,
                forwarder.address,
            );

        /// ADMIN ON V1
        // add fan address to KYC
        await userManager.connect(platformManager).addAddressToKYC(fan.address);
        // unpause collection minting

        // create 100 addresses and allocations
        const addresses = [];
        const allocations = [];
        for (let i = 0; i < 100; i++) {
            addresses.push(await ethers.Wallet.createRandom().address);
            allocations.push(5);
        }

        /// ADMIN
        // batch allowlist
        await userManager.connect(platformManager).batchAllowlist(1, nftContractV3.address, addresses, allocations);

        // check if allowlist is correct
        for (let i = 0; i < 100; i++) {
            expect(await userManager.hasAllowlist(nftContractV3.address, 1, addresses[i])).to.equal(5);
        }
    });
});
