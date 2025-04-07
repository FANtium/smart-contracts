// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @notice Struct representing an NFT sale offer
 * @dev NFT owners can create offers to sell their ERC721 NFTs for a specific USDC price
 *      Each offer represents exactly one NFT and has a limited duration
 */
struct Offer {
    address seller; // Wallet address of the seller
    address tokenAddress; // NFT contract address (Athletes token this ix 0x2b...)
    uint256 tokenId;
    uint256 amount; // In USDC, includes the fee
    uint256 fee; // In USDC, fee which should be transferred to FANtium treasury
    uint256 expiresAt; // UNIX timestamp, time when offer expires
}

/**
 * @title IFANtiumMarketplace
 * @notice Interface for the FANtium NFT marketplace contract
 * @dev Handles the creation and execution of NFT sale offers with USDC as payment
 */
interface IFANtiumMarketplace {
    // events
    event TreasuryUpdated(address newTreasury);
    event OfferExecuted(Offer offer, address indexed buyer);

    // errors
    error InvalidTreasuryAddress(address treasury);
    error OfferExpired(uint256 expiresAt, uint256 blockTimestamp);
    error SellerNotOwnerOfToken(uint256 tokenId, address seller);
    error InvalidOfferAmount(uint256 amount);
    error InvalidSellerSignature(address recoveredSigner, address seller);
    error NFTContractNotSet();
    error TreasuryNotSet();
}
