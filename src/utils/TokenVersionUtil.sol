// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.28;

/**
 * @title Claiming contract that allows payout tokens to be claimed
 * for FAN token holders.
 * @author FAANtium AG - based onMTX stuido AG.
 */
library TokenVersionUtil {
    uint256 private constant ONE_MILLION = 1_000_000;
    uint256 private constant TEN_THOUSAND = 10_000;
    uint256 public constant MAX_VERSION = 99;

    function getTokenInfo(uint256 tokenId)
        internal
        pure
        returns (uint256 collectionId, uint256 version, uint256 number)
    {
        collectionId = tokenId / ONE_MILLION;
        version = (tokenId % ONE_MILLION) / TEN_THOUSAND;
        number = tokenId % TEN_THOUSAND;
    }

    function createTokenId(
        uint256 _collectionId,
        uint256 _versionId,
        uint256 _tokenNr
    )
        internal
        pure
        returns (uint256)
    {
        uint256 tokenId = (_collectionId * ONE_MILLION) + (_versionId * TEN_THOUSAND) + _tokenNr;

        return (tokenId);
    }
}
