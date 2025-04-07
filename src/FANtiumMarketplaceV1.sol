// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IFANtiumMarketplace, Offer } from "./interfaces/IFANtiumMarketplace.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

/**
 * @title FANtium Marketplace
 * @author Alex Chernetsky, Mathieu Bour - FANtium AG
 * @notice Marketplace contract for trading FANtium NFTs
 */
contract FANtiumMarketplaceV1 is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    OwnableRoles,
    IFANtiumMarketplace,
    EIP712Upgradeable
{
    using SafeERC20 for IERC20;

    // Constants
    // ========================================================================
    /// @notice EIP-712 typehash for Offer struct
    bytes32 public constant OFFER_TYPEHASH = keccak256(
        "Offer(address seller,address tokenAddress,uint256 tokenId,uint256 amount,uint256 fee,uint256 expiresAt)"
    );

    // Roles
    // ========================================================================
    /// @notice Role identifier for addresses allowed to sign messages
    uint256 public constant SIGNER_ROLE = _ROLE_0;

    // ========================================================================
    // State variables
    // ========================================================================
    /// @notice Address of the treasury that receives marketplace fees
    address public treasury;
    /// @notice Token used for payments in the marketplace
    IERC20 public paymentToken;

    /**
     * @notice Initializes the marketplace contract
     * @param admin Address that will have admin rights
     * @param _treasury Address that will receive marketplace fees
     * @param _paymentToken Token used for payments
     */
    function initialize(address admin, address _treasury, IERC20 _paymentToken) public initializer {
        __UUPSUpgradeable_init();
        _initializeOwner(admin);
        __EIP712_init("FANtiumMarketplace", "1");
        _setTreasury(_treasury);
        paymentToken = _paymentToken;
    }

    /**
     * @notice Authorizes an upgrade to a new implementation
     * @dev Restricted to the owner
     */
    function _authorizeUpgrade(address) internal view override {
        _checkOwner();
    }

    // ========================================================================
    // Pause
    // ========================================================================
    /**
     * @notice Pauses all marketplace operations
     * @dev Can only be called by the owner
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses marketplace operations
     * @dev Can only be called by the owner
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ========================================================================
    // ERC2771
    // ========================================================================
    /**
     * @notice Checks if an address is a trusted forwarder, following the ERC2718 standard
     * @param forwarder Address to check
     * @return bool True if the address is a trusted forwarder
     */
    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return hasAllRoles(forwarder, SIGNER_ROLE);
    }

    /**
     * @dev Returns the sender of the current call, following the ERC2718 standard
     * @return sender The address of the sender
     */
    function _msgSender() internal view virtual override returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    /**
     * @dev Returns the calldata of the current call, following the ERC2718 standard
     * @return bytes The calldata of the current call
     */
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
     * @dev Sets the treasury address
     * @param _treasury New treasury address
     */
    function _setTreasury(address _treasury) internal {
        if (_treasury == address(0)) {
            revert InvalidTreasuryAddress(_treasury);
        }
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    /**
     * @notice Updates the treasury address
     * @param _treasury New treasury address
     */
    function setTreasury(address _treasury) external onlyOwner {
        _setTreasury(_treasury);
    }

    /**
     * @notice Updates the payment token
     * @param _paymentToken New payment token address
     */
    function setPaymentToken(IERC20 _paymentToken) external onlyOwner {
        paymentToken = _paymentToken;
    }

    // ========================================================================
    /**
     * @dev Verifies the seller's signature on an offer
     * @param offer The offer to verify
     * @param signature The seller's signature
     */
    function _verifySignature(Offer calldata offer, bytes calldata signature) internal view {
        bytes32 offerHash = keccak256(
            abi.encode(
                OFFER_TYPEHASH,
                offer.seller,
                offer.tokenAddress,
                offer.tokenId,
                offer.amount,
                offer.fee,
                offer.expiresAt
            )
        );

        bytes32 digest = _hashTypedDataV4(offerHash);
        address signer = ECDSA.recover(digest, signature);

        if (signer != offer.seller) {
            revert InvalidSellerSignature(signer, offer.seller);
        }
    }

    /**
     * @notice Executes a marketplace offer
     * @dev Transfers payment tokens from buyer to seller and treasury, then transfers NFT from seller to buyer
     * @param offer The offer to execute
     * @param sellerSignature The seller's signature authorizing the offer
     */
    function executeOffer(Offer calldata offer, bytes calldata sellerSignature) external {
        _verifySignature(offer, sellerSignature);

        if (offer.amount == 0) {
            revert InvalidOfferAmount(offer.amount);
        }

        if (offer.expiresAt < block.timestamp) {
            revert OfferExpired(offer.expiresAt, block.timestamp);
        }

        IERC721 token = IERC721(offer.tokenAddress);

        if (token.ownerOf(offer.tokenId) != offer.seller) {
            revert SellerNotOwnerOfToken(offer.tokenId, offer.seller);
        }

        paymentToken.safeTransferFrom(_msgSender(), offer.seller, offer.amount - offer.fee);

        if (offer.fee > 0) {
            paymentToken.safeTransferFrom(_msgSender(), treasury, offer.fee);
        }

        token.safeTransferFrom(offer.seller, _msgSender(), offer.tokenId);

        emit OfferExecuted(offer, _msgSender());
    }
}
