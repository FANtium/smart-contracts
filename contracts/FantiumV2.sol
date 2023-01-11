// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.13;

import "./FantiumBase.sol";
import "./FantiumBatchMinting.sol";
import "./FantiumBatchAllowlisting.sol";

contract FantiumV2 is FantiumBase, FantiumBatchAllowlisting, FantiumBatchMinting {
}