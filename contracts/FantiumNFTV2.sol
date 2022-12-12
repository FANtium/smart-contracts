// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./FantiumNFTV1.sol";

contract FantiumNFTV2 is FantiumNFTV1 {
    address public CLAIMING_CONTRACT;

   function initializeV2(
        address _claimingContract
    ) public reinitializer(2) {
    }

    function setClaimingContract(address _claimingContract) external onlyRole(PLATFORM_MANAGER_ROLE) {
        CLAIMING_CONTRACT = _claimingContract;
    }
}