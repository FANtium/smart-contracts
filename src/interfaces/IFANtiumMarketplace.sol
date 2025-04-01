// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/*
NFT owners may create an Offer where they express that they are ready to sell an ERC721 NFT for a certain price in USDC.
    Offers represent only 1 single NFT and has a limited duration.
*/
struct Offer {
    // Not NFTOffer as it's explicit
    address seller; // Wallet address of the seller
    address tokenAddress; // NFT contract address (Athletes token this ix 0x2b...)
    uint256 tokenId;
    uint256 amount; // In USDC base unit, includes the fee
    uint256 fee; // In USDC base unit, fee which should be transferred to FANtium treasury
    uint256 expiresAt; // UNIX timestamp, time when offer expires
}

interface IFANtiumMarketplace {
    // events
    event TreasuryAddressUpdate(address newWalletAddress);
    event OfferExecuted(Offer offer, address indexed buyer);

    // errors
    error InvalidTreasuryAddress(address treasury);
    error TreasuryAddressAlreadySet(address wallet);
    error OfferExpired(uint256 expiresAt);
}
