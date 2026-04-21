// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IERC2771 } from "./interfaces/IERC2771.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { TransferHelper } from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

/**
 * @title USDCeUniswapV3MigrationRelay
 * @author Mathieu Bour - FANtium AG
 * @notice Relay contract that swaps USDC.e to USDC via Uniswap V3 on behalf of users.
 * @dev Supports ERC-2771 meta-transactions via trusted forwarders.
 */
contract USDCeUniswapV3MigrationRelay is OwnableRoles, IERC2771 {
    using SafeERC20 for IERC20;

    /// @notice Role identifier for trusted forwarders (ERC-2771).
    uint256 public constant FORWARDER_ROLE = _ROLE_0;

    /// @notice Maximum allowed slippage in basis points (10 bps = 0.1%).
    uint256 public constant MAX_SLIPPAGE_BPS = 10;

    /// @notice Uniswap V3 pool fee tier (100 = 0.01%), the lowest tier for stablecoin pairs.
    /// @dev https://docs.uniswap.org/concepts/protocol/fees#pool-fees-tiers
    uint24 public constant POOL_FEE = 100;

    /// @notice Uniswap V3 swap router.
    ISwapRouter public immutable router;

    /// @notice Bridged USDC.e token (swap input).
    IERC20 public immutable usdcE;

    /// @notice Native USDC token (swap output).
    IERC20 public immutable usdc;

    /**
     * @notice Deploys the relay contract and configures immutable state.
     * @param owner Address that will own the contract.
     * @param forwarders Addresses to grant the trusted forwarder role.
     * @param _router Uniswap V3 SwapRouter address.
     * @param _usdcE Bridged USDC.e token address.
     * @param _usdc Native USDC token address.
     */
    constructor(address owner, address[] memory forwarders, address _router, IERC20 _usdcE, IERC20 _usdc) {
        _initializeOwner(owner);
        for (uint256 i = 0; i < forwarders.length; ++i) {
            _setRoles(forwarders[i], FORWARDER_ROLE);
        }
        router = ISwapRouter(_router);
        usdcE = _usdcE;
        usdc = _usdc;
    }

    /**
     * @notice Swaps USDC.e to USDC on behalf of the caller via Uniswap V3.
     * @dev Transfers USDC.e from the caller, approves the router, and executes an exact-input single swap.
     *      The output USDC is sent directly to the caller.
     * @param amountIn Amount of USDC.e to swap.
     */
    function delegateSwap(uint256 amountIn) external {
        address user = _msgSender();

        // Transfer USDC.e from the user to this contract
        usdcE.safeTransferFrom(user, address(this), amountIn);

        // Approve the router to spend USDC.e
        TransferHelper.safeApprove(address(usdcE), address(router), amountIn);

        uint256 amountOutMinimum = amountIn * (10_000 - MAX_SLIPPAGE_BPS) / 10_000;

        // Define the swap parameters
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(usdcE),
            tokenOut: address(usdc),
            fee: POOL_FEE,
            recipient: user,
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: 0
        });

        // Execute the swap
        router.exactInputSingle(params);
    }

    // ========================================================================
    // ERC2771
    // ========================================================================

    /**
     * @notice Checks if an address is a trusted forwarder, following the ERC-2771 standard.
     * @param forwarder Address to check.
     * @return True if the address has the FORWARDER_ROLE.
     */
    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return hasAnyRole(forwarder, FORWARDER_ROLE);
    }

    /**
     * @notice Returns the original sender of the transaction.
     * @dev If called by a trusted forwarder, extracts the sender from the last 20 bytes of calldata.
     * @return sender The original transaction sender.
     */
    function _msgSender() internal view virtual returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return msg.sender;
        }
    }

    /**
     * @notice Returns the original calldata of the transaction.
     * @dev If called by a trusted forwarder, strips the appended sender address (last 20 bytes).
     * @return The original calldata.
     */
    function _msgData() internal view virtual returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return msg.data;
        }
    }
}
