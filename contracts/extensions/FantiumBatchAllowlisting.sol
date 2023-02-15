// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.13;

import "../FantiumNFT.sol";

contract FantiumBatchAllowlisting is FantiumNFT {
    /**
     * @notice Add address to allow list.
     * @param _collectionId collection ID.
     * @param _addresses addresses to add to allow list.
     * @param _increaseAllocations allocation to the address.
     */
    function batchAllowlist(
        uint256 _collectionId,
        address[] memory _addresses,
        uint256[] memory _increaseAllocations
    )
        public
        whenNotPaused
        onlyRole(PLATFORM_MANAGER_ROLE)
        onlyValidCollectionId(_collectionId)
    {
        for (uint256 i = 0; i < _addresses.length; i++) {
            increaseAllowListAllocation(
                _collectionId,
                _addresses[i],
                _increaseAllocations[i]
            );
        }
    }
}
