// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Mock20 is ERC20 {
    constructor() ERC20("Mock20", "M20") {
        _mint(msg.sender, 1000000000 * 18 ** 6);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
