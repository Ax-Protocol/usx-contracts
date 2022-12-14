// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "solmate/utils/SafeTransferLib.sol";
import "../../../interfaces/ITreasuryTest.t.sol";
import "../../../common/Constants.t.sol";
import "./../../common/TestHelpers.t.sol";

contract TestPostSwapMint is Test, RedeemHelper {
    function testCannot_mint_after_emergency_swap() public {
        // Allocate initial funds for test
        mintForTest(TEST_DAI, DAI_AMOUNT);

        // Excluding last index (3CRV)
        for (uint256 i; i < TEST_COINS.length - 1; i++) {
            // Setup
            uint256 id = vm.snapshot();
            ITreasuryTest(address(treasury_proxy)).emergencySwapBacking(TEST_COINS[i]);
            vm.startPrank(TEST_USER);

            // Ensure TEST_USER cannot mint with any supported stable
            for (uint256 j; j < TEST_COINS.length - 1; j++) {
                deal(TEST_COINS[j], TEST_USER, TEST_AMOUNTS[j]);
                SafeTransferLib.safeApprove(ERC20(TEST_COINS[j]), address(treasury_proxy), TEST_AMOUNTS[j]);

                // Expectations
                vm.expectRevert("Unauthorized.");

                // Act: attempt to mint after emergency swap
                ITreasuryTest(address(treasury_proxy)).mint(TEST_COINS[j], TEST_AMOUNTS[j]);
            }

            // Revert blockchain state to before emergency swap for next iteration
            vm.revertTo(id);
            vm.stopPrank();
        }
    }
}
