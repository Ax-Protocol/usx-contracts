// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/interfaces/IBaseRewardPool.sol";
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

        uint256 preUsxTotalSupply = IUSXTest(address(usx_proxy)).totalSupply();
        // Excluding last index (3CRV)
        for (uint256 i; i < TEST_COINS.length - 1; i++) {
            // Expectations
            uint256 preStakedAmount = IBaseRewardPool(BASE_REWARD_POOL).balanceOf(address(treasury_proxy));
            uint256 expectedTokenAmount = calculateRedeemAmount(i, preStakedAmount, TEST_COINS[i]);

            // Pre-action assertions
            uint256 userBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
            assertEq(userBalanceUSX, preUsxTotalSupply, "Equivalence violation: userBalanceUSX and preUsxTotalSupply");
            assertEq(
                ITreasuryTest(address(treasury_proxy)).backingToken(),
                TEST_3CRV,
                "Error: backing token is not set to 3CRV"
            );
            assertEq(
                ITreasuryTest(address(treasury_proxy)).backingSwapped(),
                false,
                "Error: backing token has already been swapped"
            );
            assertEq(
                IERC20(TEST_3CRV).balanceOf(address(treasury_proxy)),
                0,
                "Equivalence violation: treasury 3CRV balance is not zero"
            );
            assertEq(
                IERC20(TEST_COINS[i]).balanceOf(address(treasury_proxy)),
                0,
                "Equivalence violation: treausury test coin balance is not zero"
            );

            // Act
            uint256 id = vm.snapshot();
            ITreasuryTest(address(treasury_proxy)).emergencySwapBacking(TEST_COINS[i]);

            /// @dev Post-action assertions
            // Ensure that no USX was burned
            assertEq(
                IUSXTest(address(usx_proxy)).totalSupply(),
                preUsxTotalSupply,
                "Equivalence violation: post-action total supply and preUsxTotalSupply"
            );
            assertEq(userBalanceUSX, preUsxTotalSupply, "Equivalence violation: userBalanceUSX and preUsxTotalSupply");

            // Ensure backingToken and backingSwapped were properly updated
            assertEq(
                ITreasuryTest(address(treasury_proxy)).backingToken(),
                TEST_COINS[i],
                "Swap failed: backingToken was not updated"
            );
            assertEq(
                ITreasuryTest(address(treasury_proxy)).backingSwapped(),
                true,
                "Swap failed: backingSwapped was not updated"
            );

            // Ensure balances were properly updated
            assertEq(
                IBaseRewardPool(BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
                0,
                "Equivalence violation: treasury staked cvx3CRV balance is not zero"
            );
            assertEq(
                IERC20(TEST_3CRV).balanceOf(address(treasury_proxy)),
                0,
                "Equivalence violation: treasury 3CRV balance is not zero"
            );
            assertEq(
                IERC20(TEST_COINS[i]).balanceOf(address(treasury_proxy)),
                expectedTokenAmount,
                "Equivalence violation: treasury test coin balance and expectedTokenAmount"
            );

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
