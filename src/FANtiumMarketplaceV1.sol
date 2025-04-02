// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./interfaces/IFANtiumMarketplace.sol"; // todo: remove extra import before merge
import { IFANtiumMarketplace, Offer } from "./interfaces/IFANtiumMarketplace.sol";
import { IFANtiumNFT } from "./interfaces/IFANtiumNFT.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

/**
 * @title FANtium Marketplace smart contract
 * @author Alex Chernetsky, Mathieu Bour - FANtium AG
 */
contract FANtiumMarketplaceV1 is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    OwnableRoles,
    IFANtiumMarketplace
{
    // Constants
    // =======================================================================
    address public constant USDC_CONTRACT_ADDRESS = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;

    // Roles
    // ========================================================================
    uint256 public constant SIGNER_ROLE = _ROLE_0;

    // ========================================================================
    // State variables
    // ========================================================================
    address public treasury; // Safe that will receive all the funds
    IFANtiumNFT public nftContract; // FANtium NFT smart contract

    function initialize(address admin) public initializer {
        __UUPSUpgradeable_init();
        _initializeOwner(admin);
    }

    /**
     * @notice Implementation of the upgrade authorization logic
     * @dev Restricted to the owner
     */
    function _authorizeUpgrade(address) internal view override {
        _checkOwner();
    }

    // ========================================================================
    // Pause
    // ========================================================================
    /**
     * @notice Update contract pause status to `_paused`.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ========================================================================
    // ERC2771
    // ========================================================================
    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return hasAllRoles(forwarder, SIGNER_ROLE);
    }

    function _msgSender() internal view virtual override returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }

    // ========================================================================
    // Setters
    // ========================================================================
    /**
     * Set treasury address - FANtium address where the funds should be transferred
     * @param wallet - address of the treasury
     */
    function setTreasuryAddress(address wallet) external onlyOwner {
        // Ensure the token address is not zero
        if (wallet == address(0)) {
            revert InvalidTreasuryAddress(wallet);
        }

        // Ensure the treasury address is not the same as the current one
        if (wallet == treasury) {
            revert TreasuryAddressAlreadySet(wallet);
        }

        // update the treasury address
        treasury = wallet;

        // emit an event for transparency
        emit TreasuryAddressUpdate(wallet);
    }

    /**
     * Set FANtium NFT contract address
     * @param _fantiumNFT - address of the NFT contract
     * todo: test
     */
    function setFANtiumNFTContract(IFANtiumNFT _fantiumNFT) external onlyOwner {
        nftContract = _fantiumNFT;
    }

    // ========================================================================
    /**
     * @notice Internal function to check if the seller signature valid utilising Solady's ECDSA library
     * The seller would sign the offer off-chain (using their wallet) before submitting it to the marketplace.
     * When a buyer wants to accept the offer, this function verifies that the signature is legitimate before allowing
     * the transaction to proceed.
     * @param offer The offer data structure containing details like seller, tokenId, amount, etc.
     * @param sellerSignature The cryptographic signature provided by the seller to authorize this offer in EIP-712
     * format
     */
    function _verifySignature(Offer calldata offer, bytes calldata sellerSignature) internal view {
        // create offer hash, keccak256() creates a 32-byte hash of the encoded data. This hash uniquely represents the
        // offer's contents
        bytes32 offerHash = keccak256(
            abi.encode(offer.seller, offer.tokenAddress, offer.tokenId, offer.amount, offer.fee, offer.expiresAt)
        );

        //  Converting to an Ethereum Signed Message Hash. This transforms the hash into an Ethereum-specific format,
        // EIP-712 compliant.
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(offerHash);

        //  Recovering the signer
        // The recover function uses the signature to determine which Ethereum address created it.
        // It performs complex elliptic curve calculations to derive this address from the signature and the message
        // hash.
        address signer = ECDSA.recover(ethSignedMessageHash, sellerSignature);

        // Verifying the signature
        if (signer != offer.seller) {
            revert InvalidSellerSignature(signer, offer.seller);
        }
    }

    //  todo: tests
    /**
     * @notice Executes seller's offer (buyer sends USDC to seller, Buyer sends USDC to FANtium (our fee), seller sends
     * NFT to buyer)
     * @param offer The seller's offer
     * @param sellerSignature The seller's signature in EIP-712 format
     */
    function executeOffer(Offer calldata offer, bytes calldata sellerSignature) external {
        // check if the offer price is valid
        if (offer.amount == 0) {
            revert InvalidOfferAmount(offer.amount);
        }

        // NFT Offer should not be executed if it has expired
        if (offer.expiresAt < block.timestamp) {
            revert OfferExpired(offer.expiresAt);
        }

        // NFT Offer should not be executed if seller is not the owner of the NFT
        if (nftContract.ownerOf(offer.tokenId) != offer.seller) {
            revert InvalidSeller(offer.seller);
        }

        // NFT Offer should not be executed if seller signature is not valid
        _verifySignature(offer, sellerSignature);

        // Buyer sends USDC to seller
        uint8 tokenDecimals = IERC20MetadataUpgradeable(USDC_CONTRACT_ADDRESS).decimals();
        uint256 expectedAmount = (offer.amount - offer.fee) * 10 ** tokenDecimals;
        SafeERC20Upgradeable.safeTransferFrom(
            IERC20Upgradeable(USDC_CONTRACT_ADDRESS), _msgSender(), offer.seller, expectedAmount
        );

        // Buyer sends USDC to FANtium (our fee),
        if (offer.fee > 0) {
            uint256 expectedFeeAmount = offer.fee * 10 ** tokenDecimals;
            SafeERC20Upgradeable.safeTransferFrom(
                IERC20Upgradeable(USDC_CONTRACT_ADDRESS), _msgSender(), treasury, expectedFeeAmount
            );
        }

        // Seller sends NFT to buyer
        nftContract.transferFrom(offer.seller, _msgSender(), offer.tokenId);

        emit OfferExecuted(offer, _msgSender());
    }
}
