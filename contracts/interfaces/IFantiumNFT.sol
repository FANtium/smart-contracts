// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

interface IFantiumNFT {
    struct Tier {
        string name;
        uint256 priceInWei;
        uint24 maxInvocations;
        uint8 tournamentEarningPercentage;
    }

    struct Collection {
        uint24 invocations;
        Tier tier;
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

    function getCollection(uint256 _collectionId)
        external
        view
        returns (Collection memory);

    function mintTo(address _to, uint256 _tokenId) external payable;

    function getPrimaryRevenueSplits(uint256 _collectionId, uint256 _price)
        external
        view
        returns (
            uint256 fantiumRevenue_,
            address payable fantiumAddress_,
            uint256 athleteRevenue_,
            address payable athleteAddress_
        );
}
