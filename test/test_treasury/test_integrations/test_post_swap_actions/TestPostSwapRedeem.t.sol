// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../../src/interfaces/IBaseRewardPool.sol";
import "../../../../src/interfaces/IERC20.sol";
import "../../../interfaces/IUSXTest.t.sol";
import "../../../interfaces/ITreasuryTest.t.sol";
import "../../../common/constants.t.sol";
import "./../../common/TestHelpers.t.sol";

contract TestEmergencySwap is Test, RedeemHelper {
    function test_redeem_after_emergency_swap(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier < 1e7);

        // Allocate initial funds for test
        mintForTest(TEST_DAI, DAI_AMOUNT * amountMultiplier);

        uint256 preUsxTotalSupply = IUSXTest(address(usx_proxy)).totalSupply();
        // Excluding last index (3CRV)
        for (uint256 i; i < TEST_COINS.length - 1; i++) {
            // Expectations
            uint256 preStakedAmount = IBaseRewardPool(BASE_REWARD_POOL).balanceOf(address(treasury_proxy));
            uint256 preExpectedTokenAmount = calculateRedeemAmount(i, preStakedAmount, TEST_COINS[i]);
            uint256 preUserBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
            uint256 preUserTokenBalance = IUSXTest(address(TEST_COINS[i])).balanceOf(TEST_USER);

            // Setup
            uint256 id = vm.snapshot();
            ITreasuryTest(address(treasury_proxy)).emergencySwapBacking(TEST_COINS[i]);

            // Pre-action assertions
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), preUsxTotalSupply);
            assertEq(preUserBalanceUSX, preUsxTotalSupply);
            assertEq(preUserTokenBalance, 0);
            assertEq(ITreasuryTest(address(treasury_proxy)).backingToken(), TEST_COINS[i]);
            assertEq(ITreasuryTest(address(treasury_proxy)).backingSwapped(), true);
            assertEq(IBaseRewardPool(BASE_REWARD_POOL).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_3CRV).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_COINS[i]).balanceOf(address(treasury_proxy)), preExpectedTokenAmount);

            // Act
            vm.startPrank(TEST_USER);
            ITreasuryTest(address(treasury_proxy)).redeem(TEST_COINS[i], preUserBalanceUSX);

            // Post-action data extraction
            uint256 postUserBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
            uint256 postUserTokenBalance = IUSXTest(address(TEST_COINS[i])).balanceOf(TEST_USER);

            /// @dev Post-action assertions
            // Ensure the correct amount of USX was redeemed
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), 0);
            assertEq(ITreasuryTest(address(treasury_proxy)).totalSupply(), 0);

            // Ensure the user's balances were properly updated
            assertEq(postUserBalanceUSX, 0);
            assertEq(postUserTokenBalance, preExpectedTokenAmount);

            // Ensure there is no 3CRV in the Treasury or liquidity gauge
            assertEq(IBaseRewardPool(BASE_REWARD_POOL).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_3CRV).balanceOf(address(treasury_proxy)), 0);

            // Ensure treasury backing amount was properly updated
            assertEq(IERC20(TEST_COINS[i]).balanceOf(address(treasury_proxy)), 0);

            /// @dev Revert blockchain state to before emergency swap for next iteration
            vm.revertTo(id);
            vm.stopPrank();
        }
    }

    /// @dev After an emergency swap, ensure redeeming fails with invalid stable
    function testCannot_redeem_after_emergency_swap_unsupported() public {
        // Allocate initial funds for test
        mintForTest(TEST_DAI, DAI_AMOUNT);

        // Excluding last index (3CRV)
        for (uint256 i; i < TEST_COINS.length - 1; i++) {
            // Setup
            uint256 id = vm.snapshot();
            uint256 userBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
            ITreasuryTest(address(treasury_proxy)).emergencySwapBacking(TEST_COINS[i]);
            vm.startPrank(TEST_USER);

            for (uint256 j; j < TEST_COINS.length - 1; j++) {
                if (TEST_COINS[j] != TEST_COINS[i]) {
                    // Expectations
                    vm.expectRevert("Invalid _stable.");

                    // Act: attempt to redeem with unsupported token after emergency swap
                    ITreasuryTest(address(treasury_proxy)).redeem(TEST_COINS[j], userBalanceUSX);
                }
            }

            /// Revert blockchain state to before minting for next iteration
            vm.revertTo(id);
            vm.stopPrank();
        }
    }
}
