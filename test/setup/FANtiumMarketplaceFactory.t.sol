// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { FANtiumMarketplaceV1 } from "../../src/FANtiumMarketplaceV1.sol";
import { Offer } from "../../src/interfaces/IFANtiumMarketplace.sol";
import { UnsafeUpgrades } from "../../src/upgrades/UnsafeUpgrades.sol";
import { BaseTest } from "../BaseTest.sol";
import { EIP712Domain } from "../utils/EIP712Signer.sol";
import { FANtiumNFTFactory } from "./FANtiumNFTFactory.t.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FANtiumMarketplaceFactory is BaseTest, FANtiumNFTFactory {
    // addresses
    address public fantiumMarketplace_admin = makeAddr("admin");
    address public fantiumMarketplace_implementation;
    address public fantiumMarketplace_proxy;
    address public fantiumMarketplace_treasury = makeAddr("treasury");

    EIP712Domain marketplaceDomain;
    IERC20 paymentToken;

    // events
    event TreasuryUpdated(address newTreasury);
    event OfferExecuted(Offer offer, address indexed buyer);

    // contracts
    FANtiumMarketplaceV1 public fantiumMarketplace;

    function setUp() public virtual override {
        FANtiumNFTFactory.setUp();

        fantiumMarketplace_implementation = address(new FANtiumMarketplaceV1());
        fantiumMarketplace_proxy = UnsafeUpgrades.deployUUPSProxy(
            fantiumMarketplace_implementation,
            abi.encodeCall(
                FANtiumMarketplaceV1.initialize, (fantiumMarketplace_admin, fantiumMarketplace_treasury, usdc)
            )
        );

        fantiumMarketplace = FANtiumMarketplaceV1(fantiumMarketplace_proxy);

        (, string memory name, string memory version, uint256 chainId, address verifyingContract,,) =
            fantiumMarketplace.eip712Domain();
        marketplaceDomain = EIP712Domain(name, version, chainId, verifyingContract);

        paymentToken = fantiumMarketplace.paymentToken();
    }

    function _hashOffer(Offer memory offer) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                fantiumMarketplace.OFFER_TYPEHASH(),
                offer.seller,
                offer.tokenAddress,
                offer.tokenId,
                offer.amount,
                offer.fee,
                offer.expiresAt
            )
        );
    }
}
