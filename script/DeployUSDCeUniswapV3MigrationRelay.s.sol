// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { USDCeUniswapV3MigrationRelay } from "../src/USDCeUniswapV3MigrationRelay.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

contract DeployUSDCeUniswapV3MigrationRelay is Script {
    error OnlyPolygonMainnet();

    /**
     * @notice Salt for CREATE2 deployment. Change this to get a different address.
     * @dev Use a unique salt per network to ensure different addresses on different chains.
     */
    bytes32 public constant SALT = keccak256("FANtium USDCeUniswapV3MigrationRelay v1");

    /// @notice FANtium multisig on Polygon.
    /// @dev https://polygonscan.com/address/0x417834e4371610BB81DC150fF47C0859b72318B0
    address public constant OWNER = 0x417834e4371610BB81DC150fF47C0859b72318B0;

    /// @notice Uniswap V3 SwapRouter02 on Polygon.
    /// @dev https://polygonscan.com/address/0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
    address public constant ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    /// @notice Bridged USDC.e on Polygon.
    /// @dev https://polygonscan.com/address/0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174
    IERC20 public constant USDC_E = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);

    /// @notice Native USDC on Polygon.
    /// @dev https://polygonscan.com/address/0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359
    IERC20 public constant USDC = IERC20(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359);

    function run() public {
        if (block.chainid != 137) {
            revert OnlyPolygonMainnet();
        }

        address[] memory forwarders = new address[](1);
        forwarders[0] = 0x90850f77DBB8F9f894aCB774b6aF31986C5Efb1D;

        bytes memory bytecode = abi.encodePacked(
            type(USDCeUniswapV3MigrationRelay).creationCode, abi.encode(OWNER, forwarders, ROUTER, USDC_E, USDC)
        );
        address predictedAddress = vm.computeCreate2Address(SALT, keccak256(bytecode));

        console.log("Predicted USDCeUniswapV3MigrationRelay address:", predictedAddress);
        console.log("Deployer address:", msg.sender);

        vm.createSelectFork(vm.rpcUrl("polygon"));
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        USDCeUniswapV3MigrationRelay relay =
            new USDCeUniswapV3MigrationRelay{ salt: SALT }(OWNER, forwarders, ROUTER, USDC_E, USDC);
        vm.stopBroadcast();

        require(address(relay) == predictedAddress, "Address mismatch");
        console.log("Deployed USDCeUniswapV3MigrationRelay at:", address(relay));
    }
}
