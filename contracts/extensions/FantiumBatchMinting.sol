// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.13;

import "../FantiumNFT.sol";

contract FantiumBatchMinting is FantiumNFT {
    /*//////////////////////////////////////////////////////////////
                                 MINTING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Batch Mints a token
     * @param _collectionId Collection ID.
     * @param _amount Amount of tokens to mint.
     */
    function batchMint(
        uint256 _collectionId,
        uint24 _amount
    ) public whenNotPaused {
        // limit amount to 10
        _amount = _amount > 10 ? 10 : _amount;

        // CHECKS
        require(isAddressKYCed(msg.sender), "Address is not KYCed");
        Collection storage collection = collections[_collectionId];
        require(collection.exists, "Collection does not exist");
        require(
            collection.launchTimestamp <= block.timestamp ||
                hasRole(PLATFORM_MANAGER_ROLE, msg.sender),
            "Collection not launched"
        );
        require(collection.isMintable, "Collection is not mintable");
        require(erc20PaymentToken != address(0), "ERC20 payment token not set");

        // multiply token price by amount
        uint256 totalPrice = collection.price *
            10 ** ERC20(erc20PaymentToken).decimals() *
            _amount;
        require(
            ERC20(erc20PaymentToken).allowance(msg.sender, address(this)) >=
                totalPrice,
            "ERC20 allowance too low"
        );

        if (collection.isPaused) {
            // if minting is paused, require address to be on allowlist
            require(
                collectionIdToAllowList[_collectionId][msg.sender] >= _amount,
                "Collection is paused or allowlist allocation insufficient"
            );
        }
        require(
            collection.invocations + _amount < collection.maxInvocations,
            "Max invocations suppassed with amount"
        );

        uint256 tokenId = (_collectionId * ONE_MILLION) +
            collection.invocations;

        // EFFECTS
        collection.invocations += _amount;

        if (collection.isPaused) {
            collectionIdToAllowList[_collectionId][msg.sender]--;
        }

        // INTERACTIONS
        _splitFunds(totalPrice, _collectionId, msg.sender);

        for (uint256 i = 0; i < _amount; i++) {
            _mint(msg.sender, tokenId + i);
            emit Mint(msg.sender, tokenId);
        }
    }
}
