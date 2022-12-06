// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/interfaces/ILiquidityGauge.sol";
import "../../src/interfaces/IERC20.sol";
import "../interfaces/IUSXTest.t.sol";
import "../interfaces/ITreasuryTest.t.sol";
import "../common/constants.t.sol";
import "./common/TestHelpers.t.sol";

contract TestRedeem is Test, RedeemHelper {
    /// @dev Test that each supported token can be redeemed in a sequential manner, without resetting chain state after each mint
    function test_redeem_sequential(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier < 1e7);

        // Allocate funds for test
        mintForTest(TEST_DAI, DAI_AMOUNT * 4 * amountMultiplier);

        uint256 usxInitialSupply = IUSXTest(address(usx_proxy)).totalSupply();
        uint256 usxTotalSupply = IUSXTest(address(usx_proxy)).totalSupply();
        uint256 stakedAmount = ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy));
        for (uint256 i; i < TEST_COINS.length; i++) {
            // Expectations
            uint256 burnAmountUSX = usxInitialSupply / TEST_COINS.length;
            uint256 curveAmountUsed = calculateCurveTokenAmount(burnAmountUSX);
            uint256 expectedRedeemAmount = calculateRedeemAmount(i, curveAmountUsed, TEST_COINS[i]);

            vm.expectEmit(true, true, true, true, address(treasury_proxy));
            emit Redemption(TEST_USER, burnAmountUSX);

            // Setup
            vm.startPrank(TEST_USER);

            // Pre-action data extraction
            uint256 preUserBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);

            // Pre-action assertions
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), usxTotalSupply);
            assertEq(preUserBalanceUSX, usxTotalSupply);

            // Act
            ITreasuryTest(address(treasury_proxy)).redeem(TEST_COINS[i], burnAmountUSX);

            /// @dev Post-action assertions
            // Ensure USX was burned
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), usxTotalSupply - burnAmountUSX);
            assertEq(IUSXTest(address(usx_proxy)).balanceOf(TEST_USER), usxTotalSupply - burnAmountUSX);
            assertEq(ITreasuryTest(address(treasury_proxy)).totalSupply(), usxTotalSupply - burnAmountUSX);

            // Ensure the user received the desired output token
            assertEq(IERC20(TEST_COINS[i]).balanceOf(TEST_USER), expectedRedeemAmount);

            // Ensure that LP tokens in liquidity gauge properly decreased
            assertEq(
                ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy)), stakedAmount - curveAmountUsed
            );

            usxTotalSupply -= burnAmountUSX;
            stakedAmount -= curveAmountUsed;
            vm.stopPrank();
        }
    }

    /// @dev Test that each supported token can be redeemed on its own, resetting chain state after each mint
    function test_redeem_independent(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier < 1e7);

        // Allocate funds for test
        mintForTest(TEST_DAI, DAI_AMOUNT * amountMultiplier);

        uint256 usxTotalSupply = IUSXTest(address(usx_proxy)).totalSupply();
        for (uint256 i; i < TEST_COINS.length; i++) {
            // Expectations
            uint256 curveAmountUsed = calculateCurveTokenAmount(usxTotalSupply);
            uint256 expectedRedeemAmount = calculateRedeemAmount(i, curveAmountUsed, TEST_COINS[i]);
            uint256 stakedAmount = ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy));

            vm.expectEmit(true, true, true, true, address(treasury_proxy));
            emit Redemption(TEST_USER, usxTotalSupply);

            // Setup
            vm.startPrank(TEST_USER);

            // Pre-action data extraction
            uint256 preUserBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);

            // Pre-action assertions
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), usxTotalSupply);
            assertEq(preUserBalanceUSX, usxTotalSupply);

            // Act
            uint256 id = vm.snapshot();
            ITreasuryTest(address(treasury_proxy)).redeem(TEST_COINS[i], usxTotalSupply);

            /// @dev Post-action assertions
            // Ensure USX was burned
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), 0);
            assertEq(IUSXTest(address(usx_proxy)).balanceOf(TEST_USER), 0);
            assertEq(ITreasuryTest(address(treasury_proxy)).totalSupply(), 0);

            // Ensure the user received the desired output token
            uint256 userERC20Balance = IERC20(TEST_COINS[i]).balanceOf(TEST_USER);
            assertEq(userERC20Balance, expectedRedeemAmount);

            // Ensure that LP tokens in liquidity gauge properly decreased
            assertEq(
                ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy)), stakedAmount - curveAmountUsed
            );

            /// @dev Revert blockchain state to before USX was redeemed for next iteration
            vm.revertTo(id);
            vm.stopPrank();
        }
    }

    function testCannot_redeem_unsupported_stable() public {
        // Test Variables
        address unsupportedStable = address(0);

        // Expectations
        vm.expectRevert("Unsupported stable.");

        // Act
        ITreasuryTest(address(treasury_proxy)).redeem(unsupportedStable, TEST_MINT_AMOUNT);
    }

    function testFail_redeem_amount(uint256 burnAmount) public {
        vm.assume(burnAmount > TEST_MINT_AMOUNT);

        // Allocate funds for test
        vm.prank(address(treasury_proxy));
        IUSXTest(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        // Give Treasury 3CRV
        uint256 curveAmount = calculateCurveTokenAmount(TEST_MINT_AMOUNT);
        deal(TEST_3CRV, address(treasury_proxy), curveAmount);

        // Expectations
        vm.expectEmit(true, true, true, true, address(treasury_proxy));
        emit Redemption(address(this), burnAmount);

        // Pre-action assertions
        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), TEST_MINT_AMOUNT);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), TEST_MINT_AMOUNT);

        // Act
        ITreasuryTest(address(treasury_proxy)).redeem(TEST_DAI, burnAmount);
    }
}
