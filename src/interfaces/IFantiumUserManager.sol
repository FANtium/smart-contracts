// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.28;

/**
 * @title FANtium User Manager Interface
 * @author Mathieu Bour - FANtium AG, based on previous work by MTX studio AG.
 */
interface IFANtiumUserManager {
    // ========================================================================
    // Structs
    // ========================================================================
    struct User {
        bool isKYCed;
        bool isIDENT;
        mapping(uint256 => uint256) contractToAllowListToSpots;
    }

    // ========================================================================
    // Know-your-customer functions
    // ========================================================================
    function setKYC(address account, bool isKYCed) external;
    function setBatchKYC(address[] memory accounts, bool[] memory isKYCed) external;
    function isKYCed(address account) external view returns (bool);

    // ========================================================================
    // INDENT functions
    // ========================================================================
    function setIDENT(address account, bool isIDENT) external;
    function setBatchIDENT(address[] memory accounts, bool[] memory isIDENT) external;
    function isIDENT(address account) external view returns (bool);

    // ========================================================================
    // AllowList functions
    // ========================================================================
    function allowlist(address account, uint256 collectionId) external view returns (uint256);
    function setAllowList(address account, uint256 collectionId, uint256 allocation) external;
    function batchSetAllowList(address[] memory accounts, uint256[] memory collectionIds, uint256[] memory allocations)
        external;
    function increaseAllowList(address account, uint256 collectionId, uint256 delta) external;
    function decreaseAllowList(address account, uint256 collectionId, uint256 delta) external;
}
