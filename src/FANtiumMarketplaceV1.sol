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
import { EIP712 } from "solady/utils/EIP712.sol";

/*
* todo: CI validate upgradability check fails
* The main issue is that the EIP712 contract from Solady has a constructor
* and Several immutable variables (_cachedThis, _cachedChainId, etc.)
* When using the OpenZeppelin upgrades pattern, you can't have constructors or immutable variables in upgradeable
contracts (or their parent contracts).*/
/**
 * @title FANtium Marketplace smart contract
 * @author Alex Chernetsky, Mathieu Bour - FANtium AG
 */
contract FANtiumMarketplaceV1 is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    OwnableRoles,
    IFANtiumMarketplace,
    EIP712
{
    // Roles
    // ========================================================================
    uint256 public constant SIGNER_ROLE = _ROLE_0;

    // ========================================================================
    // State variables
    // ========================================================================
    address public treasury; // Safe that will receive all the funds
    IFANtiumNFT public nftContract; // FANtium NFT smart contract
    address public usdcContractAddress;

    function initialize(address admin, address usdcAddress) public initializer {
        __UUPSUpgradeable_init();
        _initializeOwner(admin);
        usdcContractAddress = usdcAddress;
    }

    /**
     * @notice Implementation of the EIP712 domain name and version
     * The EIP712 contract is intended to be abstract, and it requires you to implement the _domainNameAndVersion()
     * function.
     * This function provides the domain name and version that are used to generate the EIP-712 domain separator.
     * @return name Domain name
     * @return version Domain version
     */
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        return ("FANtiumMarketplace", "1");
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
     */
    function setFANtiumNFTContract(IFANtiumNFT _fantiumNFT) external onlyOwner {
        nftContract = _fantiumNFT;
    }

    /**
     * Set USDC contract address
     * @param usdcAddress - address of the USDC contract
     */
    function setUsdcContractAddress(address usdcAddress) external onlyOwner {
        usdcContractAddress = usdcAddress;
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
        // Hash the offer struct using EIP712's typed data hashing
        bytes32 offerHash = keccak256(
            abi.encode(
                keccak256(
                    "Offer(address seller,address tokenAddress,uint256 tokenId,uint256 amount,uint256 fee,uint256 expiresAt)"
                ),
                offer.seller,
                offer.tokenAddress,
                offer.tokenId,
                offer.amount,
                offer.fee,
                offer.expiresAt
            )
        );

        // Compute the final EIP-712 hash
        bytes32 digest = _hashTypedData(offerHash);

        //  Recovering the signer
        // The recover function uses the signature to determine which Ethereum address created it.
        // It performs complex elliptic curve calculations to derive this address from the signature and the message
        // hash.
        address signer = ECDSA.recover(digest, sellerSignature);

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
        // NFT Offer should not be executed if seller signature is not valid
        _verifySignature(offer, sellerSignature);

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

        // Buyer sends USDC to seller
        uint8 tokenDecimals = IERC20MetadataUpgradeable(usdcContractAddress).decimals();
        uint256 expectedAmount = (offer.amount - offer.fee) * 10 ** tokenDecimals;
        SafeERC20Upgradeable.safeTransferFrom(
            IERC20Upgradeable(usdcContractAddress), _msgSender(), offer.seller, expectedAmount
        );

        // Buyer sends USDC to FANtium (our fee),
        if (offer.fee > 0) {
            uint256 expectedFeeAmount = offer.fee * 10 ** tokenDecimals;
            SafeERC20Upgradeable.safeTransferFrom(
                IERC20Upgradeable(usdcContractAddress), _msgSender(), treasury, expectedFeeAmount
            );
        }

        // Seller sends NFT to buyer
        nftContract.transferFrom(offer.seller, _msgSender(), offer.tokenId);

        emit OfferExecuted(offer, _msgSender());
    }
}
