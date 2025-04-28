// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script } from "forge-std/Script.sol";
import { FANtiumAthletesV9 } from "src/FANtiumAthletesV9.sol";
import { FANtiumClaimingV3 } from "src/FANtiumClaimingV3.sol";
import { FANtiumMarketplaceV1 } from "src/FANtiumMarketplaceV1.sol";
import { FANtiumTokenV1 } from "src/FANtiumTokenV1.sol";
import { FANtiumUserManagerV4 } from "src/FANtiumUserManagerV4.sol";
import { FootballTokenV1 } from "src/FootballTokenV1.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";

/**
 * @notice Deploy a new instance of the contract to the testnet.
 */
contract DeployTestnet is Script {
    address public constant ADMIN = 0xF00D14B2bf0b37177b6e13374aB4F34902Eb94fC;
    address public constant BACKEND_SIGNER = 0xCAFE914D4886B50edD339eee2BdB5d2350fdC809;
    address public constant DEPLOYER = 0xC0DE5408A46402B7Bd13678A43318c64E2c31EAA;
    address public constant TREASURY = 0x780Ab57FE57AC5D74F27E225488dd7D5cc2B9acF;

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
    IERC20 public constant PAYMENT_TOKEN = IERC20(USDC);

    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        FANtiumAthletesV9 fantiumAthletes = FANtiumAthletesV9(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FANtiumAthletesV9()), abi.encodeCall(FANtiumAthletesV9.initialize, (ADMIN))
            )
        );

        FANtiumUserManagerV4 userManager = FANtiumUserManagerV4(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FANtiumUserManagerV4()), abi.encodeCall(FANtiumUserManagerV4.initialize, (ADMIN))
            )
        );

        FANtiumClaimingV3 fantiumClaim = FANtiumClaimingV3(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FANtiumClaimingV3()), abi.encodeCall(FANtiumClaimingV3.initialize, (ADMIN))
            )
        );

        // FANtiumTokenV1 fantiumToken =
        FANtiumTokenV1(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FANtiumTokenV1()), abi.encodeCall(FANtiumTokenV1.initialize, (ADMIN))
            )
        );

        // FootballTokenV1 footballToken =
        FootballTokenV1(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FootballTokenV1()), abi.encodeCall(FootballTokenV1.initialize, (ADMIN))
            )
        );

        // FANtiumMarketplaceV1
        FANtiumMarketplaceV1(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FANtiumMarketplaceV1()),
                abi.encodeCall(FANtiumMarketplaceV1.initialize, (ADMIN, TREASURY, PAYMENT_TOKEN))
            )
        );

        vm.stopBroadcast();

        vm.startBroadcast(vm.envUint("ADMIN_PRIVATE_KEY"));
        // FANtiumNFTV6 setup
        fantiumAthletes.setUserManager(userManager);
        fantiumAthletes.setERC20PaymentToken(IERC20MetadataUpgradeable(USDC));

        fantiumAthletes.grantRole(fantiumAthletes.FORWARDER_ROLE(), GELATO_RELAYER_ERC2771);
        fantiumAthletes.grantRole(fantiumAthletes.SIGNER_ROLE(), BACKEND_SIGNER);
        fantiumAthletes.grantRole(fantiumAthletes.TOKEN_UPGRADER_ROLE(), address(fantiumClaim));

        // FANtiumUserManagerV4 setup
        userManager.setFANtiumNFT(fantiumAthletes);
        userManager.grantRole(userManager.FORWARDER_ROLE(), GELATO_RELAYER_ERC2771);
        userManager.grantRole(userManager.KYC_MANAGER_ROLE(), BACKEND_SIGNER);
        userManager.grantRole(userManager.ALLOWLIST_MANAGER_ROLE(), BACKEND_SIGNER);

        // FANtiumClaimingV2 setup
        fantiumClaim.setFANtiumNFT(fantiumAthletes);
        fantiumClaim.setUserManager(userManager);
        fantiumClaim.setGlobalPayoutToken(USDC);

        vm.stopBroadcast();
    }
}
