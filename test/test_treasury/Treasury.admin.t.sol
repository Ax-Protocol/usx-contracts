// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "./common/TestSetup.t.sol";
import "../common/Constants.t.sol";
import "../../src/treasury/interfaces/ITreasuryAdmin.sol";
import "../../src/treasury/interfaces/ICvxMining.sol";
import "../../src/treasury/interfaces/IVirtualBalanceRewardPool.sol";

contract AdminTest is Test, TreasurySetup, FundingHelper {
    function test_addSupportedStable() public {
        // Test Variables
        int128 testCurveIndex = 0;

        // Pre-action assertions
        (bool supported, int128 returnedTestCurveIndex) =
            ITreasuryAdmin(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, false, "Error: stable already supported");

        // Act
        ITreasuryAdmin(address(treasury_proxy)).addSupportedStable(TEST_STABLE, testCurveIndex);

        // Post-action assertions
        (supported, returnedTestCurveIndex) = ITreasuryAdmin(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, true, "Error: failed to add supported stable");
        assertEq(
            returnedTestCurveIndex, testCurveIndex, "Equivalence violation: returnedTestCurveIndex and testCurveIndex"
        );
    }

    function testCannot_addSupportedStable_unauthorized() public {
        // Test Variables
        int128 testCurveIndex = 0;

        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(TEST_ADDRESS);
        ITreasuryAdmin(address(treasury_proxy)).addSupportedStable(TEST_STABLE, testCurveIndex);
    }

    function test_removeSupportedStable() public {
        // Setup
        ITreasuryAdmin(address(treasury_proxy)).addSupportedStable(TEST_STABLE, 0);

        // Pre-action assertions
        (bool supported, int128 returnedTestCurveIndex) =
            ITreasuryAdmin(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, true, "Error: stable not supported");
        assertEq(returnedTestCurveIndex, 0, "Equivalence violation: returnedTestCurveIndex and testCurveIndex");

        // Act
        ITreasuryAdmin(address(treasury_proxy)).removeSupportedStable(TEST_STABLE);

        // Post-action assertions
        (supported, returnedTestCurveIndex) = ITreasuryAdmin(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, false, "Error: failed to remove supported stable");
    }

    function testCannot_removeSupportedStable_unauthorized() public {
        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(TEST_ADDRESS);
        ITreasuryAdmin(address(treasury_proxy)).removeSupportedStable(TEST_STABLE);
    }

    function test_extractERC20_treasury(uint256 amount) public {
        // Assumptions
        vm.assume(amount > 0 && amount < 1e6);

        // Setup: deal test tokens to treasury
        deal(DAI, address(treasury_proxy), amount);
        deal(USDC, address(treasury_proxy), amount);
        deal(USDT, address(treasury_proxy), amount);
        deal(_3CRV, address(treasury_proxy), amount);

        // Setup: mint some USX so treasury has backing
        _mintForTest(DAI, DAI_AMOUNT);

        for (uint256 i = 0; i < TEST_COINS.length; i++) {
            // Pre-action assertions
            assertEq(
                IERC20(TEST_COINS[i]).balanceOf(address(treasury_proxy)),
                amount,
                "Equivalence violation: treausury test coin balance and amount."
            );

            // Act
            ITreasuryAdmin(address(treasury_proxy)).extractERC20(TEST_COINS[i]);

            // Post-action assertions
            assertEq(
                IERC20(TEST_COINS[i]).balanceOf(address(treasury_proxy)),
                0,
                "Equivalence violation: treausury test coin balance is not zero."
            );
            assertEq(
                IERC20(TEST_COINS[i]).balanceOf(address(this)),
                amount,
                "Equivalence violation: owner test coin balance and amount."
            );
        }
    }

    function testCannot_extractERC20_treasury_unauthorized(address sender, uint256 amount) public {
        // Assumptions
        vm.assume(amount > 0 && amount < 1e6);
        vm.assume(sender != address(this));

        // Setup: deal bridge the tokens
        deal(DAI, address(treasury_proxy), amount);
        deal(USDC, address(treasury_proxy), amount);
        deal(USDT, address(treasury_proxy), amount);
        deal(_3CRV, address(treasury_proxy), amount);

        for (uint256 i = 0; i < TEST_COINS.length; i++) {
            // Exptectations
            vm.expectRevert("Ownable: caller is not the owner");

            // Act: pranking as other addresses
            vm.prank(sender);
            ITreasuryAdmin(address(treasury_proxy)).extractERC20(TEST_COINS[i]);
        }
    }
}
