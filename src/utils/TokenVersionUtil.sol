// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.13;

/**
 * @title Claiming contract that allows payout tokens to be claimed
 * for FAN token holders.
 * @author FAANtium AG - based onMTX stuido AG.
 */
library TokenVersionUtil {
    uint256 constant ONE_MILLION = 1_000_000;
    uint256 constant TEN_THOUSAND = 10_000;

    /*///////////////////////////////////////////////////////////////
                            INTERNAL 
    //////////////////////////////////////////////////////////////*/

    function getTokenInfo(uint256 _tokenId) internal pure returns (uint256, uint256, uint256) {
        uint256 collectionOfToken = _tokenId / ONE_MILLION;
        uint256 versionOfToken = (_tokenId % ONE_MILLION) / TEN_THOUSAND;
        uint256 tokenNr = _tokenId % TEN_THOUSAND;

        return (collectionOfToken, versionOfToken, tokenNr);
    }

    function createTokenId(uint256 _collectionId, uint256 _versionId, uint256 _tokenNr)
        internal
        pure
        returns (uint256)
    {
        uint256 tokenId = (_collectionId * ONE_MILLION) + (_versionId * TEN_THOUSAND) + _tokenNr;

        return (tokenId);
    }
}
