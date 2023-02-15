// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the IFantiumNFT
 */
interface IFantiumNFT {
    /**
     * @notice upgrades token version. Old token gets burned and new token gets minted to owner of Token
     * @param _tokenId TokenID to be upgraded
     * @return bool if upgrade successfull it returns true
     */
    function upgradeTokenVersion(uint256 _tokenId) external returns (bool);

    /**
     * @notice get royalties for secondary market transfers of token
     * @param _tokenId tokenId of NFT
     * @return recipients array of recepients of royalties
     * @return bps array of bps of royalties
     */

    function getRoyalties(
        uint256 _tokenId
    )
        external
        view
        returns (address payable[] memory recipients, uint256[] memory bps);

    /**
     * @notice get collection athlete address
     * @param _collectionId collectionId of NFTs
     * @return address of athlete
     */

    function getCollectionAthleteAddress(
        uint256 _collectionId
    ) external view returns (address);

    /**
     * @notice get earnings share per token of collection
     * @param _collectionId collectionId of NFT
     * @return uint256 tournament share per token of collection
     */

    function getTournamentEarnings(
        uint256 _collectionId
    ) external view returns (uint256, uint256);

    /**
     * @notice get earnings share per token of collection
     * @param _collectionId collectionId of NFT
     * @return uint256 other earnings share per token of collection
     */

    function getOtherEarnings(
        uint256 _collectionId
    ) external view returns (uint256, uint256);

    /**
     * @notice check if collection exists
     * @param _collectionId collectionId of NFT
     * @return bool true if collection exists
     */

    function getCollectionExists(
        uint256 _collectionId
    ) external view returns (bool);
}
