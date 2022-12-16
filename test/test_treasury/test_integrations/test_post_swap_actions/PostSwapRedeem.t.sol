// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "./../../common/TestHelpers.t.sol";

import "../../../../src/treasury/interfaces/IBaseRewardPool.sol";
import "../../../../src/common/interfaces/IERC20.sol";
import "../../../../src/common/interfaces/IUSXAdmin.sol";
import "../../../../src/treasury/interfaces/ITreasuryAdmin.sol";

import "../../../common/Constants.t.sol";

contract EmergencySwapTest is Test, RedeemHelper {
    function testCannot_redeem_after_emergency_swap() public {
        // Allocate initial funds for test
        mintForTest(TEST_DAI, DAI_AMOUNT);

        // Excluding last index (3CRV)
        for (uint256 i; i < TEST_COINS.length - 1; i++) {
            // Setup
            uint256 id = vm.snapshot();
            uint256 userBalanceUSX = IUSXAdmin(address(usx_proxy)).balanceOf(TEST_USER);
            ITreasuryAdmin(address(treasury_proxy)).emergencySwapBacking(TEST_COINS[i]);
            vm.startPrank(TEST_USER);

            // Ensure TEST_USER cannot redeem for any supported stable
            for (uint256 j; j < TEST_COINS.length - 1; j++) {
                // Expectations: no more cvxCRV to unstake after emergency swap
                vm.expectRevert("SafeMath: subtraction overflow");

                // Act: attempt to redeem after emergency swap
                ITreasuryAdmin(address(treasury_proxy)).redeem(TEST_COINS[j], userBalanceUSX);
            }

            /// Revert blockchain state to before emerfency swap for next iteration
            vm.revertTo(id);
            vm.stopPrank();
        }
    }
}
