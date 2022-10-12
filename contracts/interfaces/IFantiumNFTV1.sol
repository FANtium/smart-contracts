// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";


/**
 * @title Interface of FANtium ERC721 contract V1.
 * @author MTX stuido AG.
 */

 interface IFantiumNFTV1 {

    function getCollectionData(uint256 _collectionId)
        external
        view
        returns (
            uint24 invocations,
            uint24 maxInvocations,
            uint256 priceInWei,
            bool paused,
            string memory name,
            string memory athleteName,
            string memory collectionBaseURI,
            address payable athleteAddress,
            uint8 athletePrimarySalesPercentage,
            uint8 athleteSecondarySalesPercentage
        );

    function mint(address _to, uint256 _collectionId, address _by)
        external
        returns (uint256 _tokenId);

     function getPrimaryRevenueSplits(uint256 _collectionId, uint256 _price)
        external
        view
        returns (
            uint256 fantiumRevenue_,
            address payable fantiumAddress_,
            uint256 athleteRevenue_,
            address payable athleteAddress_
        );

    // function getClaimingStatusForToken(uint256 _tokenId)
    //     external
    //     view
    //     returns (bool);

 }

