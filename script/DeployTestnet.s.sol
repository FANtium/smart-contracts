// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {
    IERC20MetadataUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { Script } from "forge-std/Script.sol";
import { FANtiumAthletesV12 } from "src/FANtiumAthletesV12.sol";
import { FANtiumClaimingV5 } from "src/FANtiumClaimingV5.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";

/**
 * @notice Deploy a new instance of the contract to the testnet.
 */
contract DeployTestnet is Script {
    address public constant ADMIN = 0xF00D14B2bf0b37177b6e13374aB4F34902Eb94fC;
    address public constant BACKEND_SIGNER = 0xCAFE914D4886B50edD339eee2BdB5d2350fdC809;
    address public constant DEPLOYER = 0xC0DE5408A46402B7Bd13678A43318c64E2c31EAA;

    /**
     * @dev Gelato relayer for ERC2771
     * See https://docs.gelato.network/web3-services/relay/supported-networks#gelatorelay1balanceerc2771.sol
     */
    address public constant GELATO_RELAYER_ERC2771 = 0x70997970c59CFA74a39a1614D165A84609f564c7;
    /**
     * @dev USDC token on Polygon Amoy.
     * See Circle announcement: https://developers.circle.com/stablecoins/migrate-from-mumbai-to-amoy-testnet
     */
    address public constant USDC = 0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582;

    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        FANtiumAthletesV12 fantiumAthletes = FANtiumAthletesV12(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FANtiumAthletesV12()), abi.encodeCall(FANtiumAthletesV12.initialize, (ADMIN))
            )
        );

        FANtiumClaimingV5 fantiumClaim = FANtiumClaimingV5(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FANtiumClaimingV5()), abi.encodeCall(FANtiumClaimingV5.initialize, (ADMIN))
            )
        );

        vm.stopBroadcast();

        vm.startBroadcast(vm.envUint("ADMIN_PRIVATE_KEY"));
        // FANtiumNFTV6 setup
        fantiumAthletes.setERC20PaymentToken(IERC20MetadataUpgradeable(USDC));

        fantiumAthletes.grantRole(fantiumAthletes.FORWARDER_ROLE(), GELATO_RELAYER_ERC2771);
        fantiumAthletes.grantRole(fantiumAthletes.SIGNER_ROLE(), BACKEND_SIGNER);
        fantiumAthletes.grantRole(fantiumAthletes.TOKEN_UPGRADER_ROLE(), address(fantiumClaim));

        // FANtiumClaimingV2 setup
        fantiumClaim.setFANtiumNFT(fantiumAthletes);
        fantiumClaim.setGlobalPayoutToken(USDC);

        vm.stopBroadcast();
    }
}
