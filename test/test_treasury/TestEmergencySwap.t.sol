// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/interfaces/ILiquidityGauge.sol";
import "../../src/interfaces/IERC20.sol";
import "../interfaces/IUSXTest.t.sol";
import "../interfaces/ITreasuryTest.t.sol";
import "../common/constants.t.sol";
import "./common/TestHelpers.t.sol";

contract TestEmergencySwap is Test, RedeemHelper {
    /// @dev Test that 3CRV can be swapped to each supported stable
    function test_emergency_swap(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier < 1e7);

        // Allocate funds for test
        mintForTest(TEST_DAI, DAI_AMOUNT * amountMultiplier);

        uint256 usxTotalSupply = IUSXTest(address(usx_proxy)).totalSupply();
        // Excluding last index (3CRV)
        for (uint256 i; i < TEST_COINS.length - 1; i++) {
            // Expectations
            uint256 preStakedAmount = ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy));
            uint256 expectedTokenAmount = calculateRedeemAmount(i, preStakedAmount, TEST_COINS[i]);

            // Pre-action assertions
            uint256 userBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), usxTotalSupply);
            assertEq(userBalanceUSX, usxTotalSupply);
            assertEq(ITreasuryTest(address(treasury_proxy)).backingToken(), TEST_3CRV);
            assertEq(ITreasuryTest(address(treasury_proxy)).backingSwapped(), false);
            assertEq(IERC20(TEST_3CRV).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_COINS[i]).balanceOf(address(treasury_proxy)), 0);

            // Act
            uint256 id = vm.snapshot();
            ITreasuryTest(address(treasury_proxy)).emergencySwapBacking(TEST_COINS[i]);

            /// @dev Post-action assertions
            // Ensure that no USX was burned
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), usxTotalSupply);
            assertEq(userBalanceUSX, usxTotalSupply);

            // Ensure backingToken and backingSwapped were properly updated
            assertEq(ITreasuryTest(address(treasury_proxy)).backingToken(), TEST_COINS[i]);
            assertEq(ITreasuryTest(address(treasury_proxy)).backingSwapped(), true);

            // Ensure balances were properly updated
            assertEq(ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_3CRV).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_COINS[i]).balanceOf(address(treasury_proxy)), expectedTokenAmount);

            /// @dev Revert blockchain state to before emergency swap for next iteration
            vm.revertTo(id);
        }
    }

    /// @dev Test that emergency swap fails if new backingToken is unsupported
    function testCannot_emergency_swap_unsupported() public {
        // Allocate initial funds for test
        mintForTest(TEST_DAI, DAI_AMOUNT);

        // Expectations
        vm.expectRevert("Token not supported.");

        // Act: attempt to perform emergency swap to an unsupported token
        ITreasuryTest(address(treasury_proxy)).emergencySwapBacking(TEST_3CRV);
    }
}
