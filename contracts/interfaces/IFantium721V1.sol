// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "../FantiumAbstract.sol";


/**
 * @title Interface of FANtium ERC721 contract V1.
 * @author MTX stuido AG.
 */

 interface IFantium721V1 is FantiumAbstract {

    //  struct Collection {
    //     uint24 invocations;
    //     uint24 maxInvocations;
    //     uint256 priceInWei;
    //     bool paused;
    //     string name;
    //     string athleteName;
    //     string collectionBaseURI;
    //     address payable athleteAddress;
    //     // packed uint: max of 100, max uint8 = 255
    //     uint8 athletePrimarySalesPercentage;
    //     // packed uint: max of 100, max uint8 = 255
    //     uint8 athleteSecondarySalesPercentage;
    // }
    
    /**
     * @notice Returns the collection struct for a given collectionId.
     * @param _collectionId uint256 ID of the collection.
     * @return Collection struct.
     */
    function getCollection(uint256 _collectionId) external view returns (Collection memory);

    // /**
    //  * @notice Returns the collection struct for a given collectionId.
    //  * @param _collectionId uint256 ID of the collection.
    //  * @return Collection struct.
    //  */
    // function getCollectionName(uint256 _collectionId) external view returns (string memory);

    // /**
    //  * @notice Returns the collection struct for a given collectionId.
    //  * @param _collectionId uint256 ID of the collection.
    //  * @return Collection struct.
    //  */
    // function getCollectionAthleteName(uint256 _collectionId) external view returns (string memory);

    // /**
    //  * @notice Returns the collection struct for a given collectionId.
    //  * @param _collectionId uint256 ID of the collection.
    //  * @return Collection struct.
    //  */
    // function getCollectionBaseURI(uint256 _collectionId) external view returns (string memory);

    // /**
    //  * @notice Returns the collection struct for a given collectionId.
    //  * @param _collectionId uint256 ID of the collection.
    //  * @return Collection struct.
    //  */
    // function getCollectionPriceInWei(uint256 _collectionId) external view returns (uint256);

    // /**
    //  * @notice Returns the collection struct for a given collectionId.
    //  * @param _collectionId uint256 ID of the collection.
    //  * @return Collection struct.
    //  */
    // function getCollectionMaxInvocations(uint256 _collectionId) external view returns (uint24);

    // /**
    //  * @notice Returns the collection struct for a given collectionId.
    //  * @param _collectionId uint256 ID of the collection.
    //  * @return Collection struct.
    //  */
    // function getCollectionInvocations(uint256 _collectionId) external view returns (uint24);

    // /**
    //  * @notice Returns the collection struct for a given collectionId.
    //  * @param _collectionId uint256 ID of the collection.
    //  * @return Collection struct.
    //  */
    // function getCollectionPaused(uint256 _collectionId) external view returns (bool);

    // /**
    //  * @notice Returns the collection struct for a given collectionId.
    //  * @param _collectionId uint256 ID of the collection.
    //  * @return Collection struct.
    //  */
    // function getCollectionAthleteAddress(uint256 _collectionId) external view returns (address payable);
 }

