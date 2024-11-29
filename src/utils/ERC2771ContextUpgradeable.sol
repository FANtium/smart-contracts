// SPDX-License-Identifier: MIT
// Forked by FANtium AG to relax how trusted forwarder is checked.
pragma solidity ^0.8.9;

abstract contract ERC2771ContextUpgradeable {
    mapping(address => bool) public trustedForwarders;
    uint256 private constant _CONTEXT_SUFFIX_LENGTH = 20;

    function _grantTrustedForwarder(address forwarder) internal virtual {
        trustedForwarders[forwarder] = true;
    }

    function _revokeTrustedForwarder(address forwarder) internal virtual {
        trustedForwarders[forwarder] = false;
    }

    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return trustedForwarders[forwarder];
    }

    function _msgSender() internal view virtual returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), _CONTEXT_SUFFIX_LENGTH)))
            }
        } else {
            return msg.sender;
        }
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - _CONTEXT_SUFFIX_LENGTH];
        } else {
            return msg.data;
        }
    }
}
