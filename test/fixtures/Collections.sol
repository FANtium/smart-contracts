// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Collection} from "../../src/interfaces/IFANtiumNFT.sol";

library Collections {
    address public constant ATHLETE = 0xcf8752CdE9Cc41C2b3E26be5AB8b101920e02445;
    address public constant TREASURY_PRIMARY = 0x032bb5B61f0e3f67FeDC85b642E060d74A4eBC2e;

    function bronze() external pure returns (Collection memory) {
        return
            Collection({
                exists: true,
                launchTimestamp: 0,
                isMintable: true,
                isPaused: false,
                invocations: 0,
                price: 99,
                maxInvocations: 600,
                tournamentEarningShare1e7: 800,
                athleteAddress: payable(ATHLETE),
                athletePrimarySalesBPS: 9000,
                athleteSecondarySalesBPS: 500,
                fantiumSalesAddress: payable(TREASURY_PRIMARY),
                fantiumSecondarySalesBPS: 200,
                otherEarningShare1e7: 100
            });
    }

    function silver() external pure returns (Collection memory) {
        return
            Collection({
                exists: true,
                launchTimestamp: 0,
                isMintable: true,
                isPaused: false,
                invocations: 0,
                price: 499,
                maxInvocations: 300,
                tournamentEarningShare1e7: 800,
                athleteAddress: payable(ATHLETE),
                athletePrimarySalesBPS: 9000,
                athleteSecondarySalesBPS: 500,
                fantiumSalesAddress: payable(TREASURY_PRIMARY),
                fantiumSecondarySalesBPS: 200,
                otherEarningShare1e7: 100
            });
    }

    function gold() external pure returns (Collection memory) {
        return
            Collection({
                exists: true,
                launchTimestamp: 0,
                isMintable: true,
                isPaused: false,
                invocations: 0,
                price: 9999,
                maxInvocations: 100,
                tournamentEarningShare1e7: 800,
                athleteAddress: payable(ATHLETE),
                athletePrimarySalesBPS: 9000,
                athleteSecondarySalesBPS: 500,
                fantiumSalesAddress: payable(TREASURY_PRIMARY),
                fantiumSecondarySalesBPS: 200,
                otherEarningShare1e7: 100
            });
    }

    function closed() external pure returns (Collection memory) {
        return
            Collection({
                exists: true,
                launchTimestamp: 0,
                isMintable: true,
                isPaused: false,
                invocations: 0,
                price: 99 * 10 ** 6,
                maxInvocations: 250,
                tournamentEarningShare1e7: 800,
                athleteAddress: payable(ATHLETE),
                athletePrimarySalesBPS: 9000,
                athleteSecondarySalesBPS: 500,
                fantiumSalesAddress: payable(TREASURY_PRIMARY),
                fantiumSecondarySalesBPS: 200,
                otherEarningShare1e7: 100
            });
    }

    function paused() external pure returns (Collection memory) {
        return
            Collection({
                exists: true,
                launchTimestamp: 0,
                isMintable: true,
                isPaused: true,
                invocations: 0,
                price: 99,
                maxInvocations: 250,
                tournamentEarningShare1e7: 800,
                athleteAddress: payable(ATHLETE),
                athletePrimarySalesBPS: 9000,
                athleteSecondarySalesBPS: 500,
                fantiumSalesAddress: payable(TREASURY_PRIMARY),
                fantiumSecondarySalesBPS: 200,
                otherEarningShare1e7: 100
            });
    }
}
