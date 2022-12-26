// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "./common/TestSetup.t.sol";
import "../common/Constants.t.sol";

import "../../src/treasury/interfaces/IBaseRewardPool.sol";
import "../../src/common/interfaces/IERC20.sol";
import "../../src/common/interfaces/IUSXAdmin.sol";
import "../../src/treasury/interfaces/ITreasuryAdmin.sol";

contract EmergencySwapTest is Test, RedeemHelper {
    /// @dev Test that 3CRV can be swapped to each supported stable
    function test_emergency_swap(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier < 1e7);

        // Allocate funds for test
        _mintForTest(DAI, DAI_AMOUNT * amountMultiplier);

        uint256 preUsxTotalSupply = IUSXAdmin(address(usx_proxy)).totalSupply();
        // Excluding last index (3CRV)
        for (uint256 i; i < TEST_COINS.length - 1; i++) {
            // Expectations
            uint256 preStakedAmount = IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy));
            uint256 expectedTokenAmount = _calculateRedeemAmount(i, preStakedAmount, TEST_COINS[i]);

            // Pre-action assertions
            uint256 userBalanceUSX = IUSXAdmin(address(usx_proxy)).balanceOf(TEST_USER);
            assertEq(userBalanceUSX, preUsxTotalSupply, "Equivalence violation: userBalanceUSX and preUsxTotalSupply");
            assertEq(
                IERC20(_3CRV).balanceOf(address(treasury_proxy)),
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
            ITreasuryAdmin(address(treasury_proxy)).emergencySwapBacking(TEST_COINS[i]);

            /// @dev Post-action assertions
            // Ensure that no USX was burned
            assertEq(
                IUSXAdmin(address(usx_proxy)).totalSupply(),
                preUsxTotalSupply,
                "Equivalence violation: post-action total supply and preUsxTotalSupply"
            );
            assertEq(userBalanceUSX, preUsxTotalSupply, "Equivalence violation: userBalanceUSX and preUsxTotalSupply");

            // Ensure balances were properly updated
            assertEq(
                IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
                0,
                "Equivalence violation: treasury staked cvx3CRV balance is not zero"
            );
            assertEq(
                IERC20(_3CRV).balanceOf(address(treasury_proxy)),
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
        _mintForTest(DAI, DAI_AMOUNT);

        // Expectations
        vm.expectRevert("Token not supported.");

        // Act: attempt to perform emergency swap to an unsupported token
        ITreasuryAdmin(address(treasury_proxy)).emergencySwapBacking(_3CRV);
    }
}
