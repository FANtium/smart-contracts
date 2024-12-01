// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the IFantiumUserManager
 */
interface IFantiumUserManager {
    /**
     * @dev All events are emitted in the FantomUserManager contract.
     */
    event AddressAddedToKYC(address indexed _address);
    event AddressRemovedFromKYC(address indexed _address);
    event AddressAddedToIDENT(address indexed _address);
    event AddressRemovedFromIDENT(address indexed _address);
    event AddressAddedToAllowList(uint256 collectionId, address indexed _address);
    event AddressRemovedFromAllowList(uint256 collectionId, address indexed _address);

    /**
     * @notice Check if address is KYCed.
     * @param _address address to be checked.
     * @return isKYCed true if address is KYCed.
     */
    function isAddressKYCed(address _address) external view returns (bool);

    /**
     * @notice Check if address is KYCed.
     * @param _address address to be checked.
     * @return isIDENT true if address is KYCed.
     */
    function isAddressIDENT(address _address) external view returns (bool);

    /**
     * @notice Check if address is allowlisted on a certain contract with a certain collection.
     * @param _contractAddress ContractAddress of the NFT contract that allowlist applies to
     * @param _collectionId CollectionId of the NFT contract that allowlist applies to
     * @param _address address to be checked for alliwlist.
     * @return hasAllowlist true if address is allowlisted.
     */
    function hasAllowlist(
        address _contractAddress,
        uint256 _collectionId,
        address _address
    ) external view returns (uint256);

    /**
     * @notice Reduce Allowlist for NFT contract
     * @param _contractAddress ContractAddress of the NFT contract that allowlist applies to
     * @param _collectionId CollectionId of the NFT contract that allowlist applies to
     * @param _address address to be reduced the allowlist for.
     * @return _reduceAllocation amount the allowlist gets reduced by.
     */
    function reduceAllowListAllocation(
        uint256 _collectionId,
        address _contractAddress,
        address _address,
        uint256 _reduceAllocation
    ) external returns (uint256);
}
