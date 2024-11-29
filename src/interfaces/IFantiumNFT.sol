// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

struct Collection {
    bool exists;
    uint256 launchTimestamp;
    bool isMintable;
    bool isPaused;
    uint24 invocations;
    uint256 price;
    uint256 maxInvocations;
    uint256 tournamentEarningShare1e7;
    address payable athleteAddress;
    uint256 athletePrimarySalesBPS;
    uint256 athleteSecondarySalesBPS;
    address payable fantiumSalesAddress;
    uint256 fantiumSecondarySalesBPS;
    uint256 otherEarningShare1e7;
}
/**
 * @dev Interface of the IFANtiumNFT
 */
interface IFANtiumNFT is IERC721Upgradeable {
    function collections(uint256 _collectionId) external view returns (Collection memory);

    /**
     * @notice upgrades token version. Old token gets burned and new token gets minted to owner of Token
     * @param _tokenId TokenID to be upgraded
     * @return bool if upgrade successfull it returns true
     */
    function upgradeTokenVersion(uint256 _tokenId) external returns (bool);

    function getPrimaryRevenueSplits(
        uint256 _collectionId,
        uint256 _price
    )
        external
        view
        returns (
            uint256 fantiumRevenue_,
            address payable fantiumAddress_,
            uint256 athleteRevenue_,
            address payable athleteAddress_
        );

    /**
     * @notice get royalties for secondary market transfers of token
     * @param _tokenId tokenId of NFT
     * @return recipients array of recepients of royalties
     * @return bps array of bps of royalties
     */

    function getRoyalties(
        uint256 _tokenId
    ) external view returns (address payable[] memory recipients, uint256[] memory bps);

    /**
     * @notice get collection athlete address
     * @param _collectionId collectionId of NFTs
     * @return address of athlete
     */

    function getCollectionAthleteAddress(uint256 _collectionId) external view returns (address);

    /**
     * @notice get earnings share per token of collection
     * @param _collectionId collectionId of NFT
     * @return uint256 tournament share in 1e7 per token of collection
     * @return uint256 other share in 1e7 per token of collection
     */

    function getEarningsShares1e7(uint256 _collectionId) external view returns (uint256, uint256);

    /**
     * @notice check if collection exists
     * @param _collectionId collectionId of NFT
     * @return bool true if collection exists
     */

    function getCollectionExists(uint256 _collectionId) external view returns (bool);

    /**
     * @notice get tokens minted per collection
     * @param _collectionId collectionId of NFT
     * @return uint24 returns amount of minted tokens of collection
     */

    function getMintedTokensOfCollection(uint256 _collectionId) external view returns (uint24);

    function mintTo(uint256 collectionId, uint24 quantity, address recipient) external;
}
