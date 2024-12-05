// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { FANtiumClaimingV2 } from "src/FANtiumClaimingV2.sol";
import { FANtiumNFTV6 } from "src/FANtiumNFTV6.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { FANtiumUserManagerV2 } from "src/FANtiumUserManagerV2.sol";

/**
 * @notice Deploy a new instance of the FANtiumNFTV6 contract to the testnet.
 */
contract DeployTestnetV5 is Script {
    address public constant ADMIN = 0xF00D14B2bf0b37177b6e13374aB4F34902Eb94fC;
    address public constant BACKEND_SIGNER = 0xCAFE914D4886B50edD339eee2BdB5d2350fdC809;
    address public constant DEPLOYER = 0xC0DE5408A46402B7Bd13678A43318c64E2c31EAA;

    /**
     * @dev Gelato relayer for ERC2771
     * See https://docs.gelato.network/web3-services/relay/supported-networks#gelatorelay1balanceerc2771.sol
     */
    address public constant GELATO_RELAYER_ERC2771 = 0x70997970c59CFA74a39a1614D165A84609f564c7;
    address[2] public MANAGERS = [
        0x65b3e69674927e10D6AFA307944F90580Df86b64, // @mat
        0x514bcCad42f0F8584B7e1fEdccD2aaA4eE2f2c8E // @alex
    ];

    /**
     * @dev USDC token on Polygon Amoy.
     * See Circle announcement: https://developers.circle.com/stablecoins/migrate-from-mumbai-to-amoy-testnet
     */
    address public constant USDC = 0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582;

    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        FANtiumNFTV6 fantiumNFT = FANtiumNFTV6(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FANtiumNFTV6()), abi.encodeCall(FANtiumNFTV6.initialize, (ADMIN))
            )
        );

        FANtiumUserManagerV2 userManager = FANtiumUserManagerV2(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FANtiumUserManagerV2()), abi.encodeCall(FANtiumUserManagerV2.initialize, (ADMIN))
            )
        );

        FANtiumClaimingV2 fantiumClaim = FANtiumClaimingV2(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FANtiumClaimingV2()), abi.encodeCall(FANtiumClaimingV2.initialize, (ADMIN))
            )
        );
        vm.stopBroadcast();

        vm.startBroadcast(vm.envUint("ADMIN_PRIVATE_KEY"));
        // FANtiumNFTV6 setup
        fantiumNFT.setUserManager(userManager);
        fantiumNFT.setERC20PaymentToken(USDC);

        for (uint256 i = 0; i < MANAGERS.length; i++) {
            fantiumNFT.grantRole(fantiumNFT.MANAGER_ROLE(), MANAGERS[i]);
        }
        fantiumNFT.grantRole(fantiumNFT.FORWARDER_ROLE(), GELATO_RELAYER_ERC2771);
        fantiumNFT.grantRole(fantiumNFT.SIGNER_ROLE(), BACKEND_SIGNER);
        fantiumNFT.grantRole(fantiumNFT.TOKEN_UPGRADER_ROLE(), address(fantiumClaim));

        // FANtiumUserManagerV2 setup
        userManager.grantRole(userManager.FORWARDER_ROLE(), GELATO_RELAYER_ERC2771);
        for (uint256 i = 0; i < MANAGERS.length; i++) {
            userManager.grantRole(userManager.MANAGER_ROLE(), MANAGERS[i]);
        }
        userManager.grantRole(userManager.KYC_MANAGER_ROLE(), BACKEND_SIGNER);
        userManager.grantRole(userManager.ALLOWLIST_MANAGER_ROLE(), BACKEND_SIGNER);

        // FANtiumClaimingV2 setup
        fantiumClaim.setFantiumNFT(fantiumNFT);
        fantiumClaim.setUserManager(userManager);
        fantiumClaim.setGlobalPayoutToken(USDC);
        for (uint256 i = 0; i < MANAGERS.length; i++) {
            fantiumClaim.grantRole(fantiumClaim.MANAGER_ROLE(), MANAGERS[i]);
        }

        vm.stopBroadcast();
    }
}
