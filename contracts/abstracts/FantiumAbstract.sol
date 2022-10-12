// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract FantiumAbstract {
        struct Collection {
        uint24 invocations;
        uint24 maxInvocations;
        uint256 priceInWei;
        bool paused;
        string name;
        string athleteName;
        string collectionBaseURI;
        address payable athleteAddress;
        // packed uint: max of 100, max uint8 = 255
        uint8 athletePrimarySalesPercentage;
        // packed uint: max of 100, max uint8 = 255
        uint8 athleteSecondarySalesPercentage;
    }
}