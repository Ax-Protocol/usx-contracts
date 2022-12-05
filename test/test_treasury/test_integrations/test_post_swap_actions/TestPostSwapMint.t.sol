// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "solmate/utils/SafeTransferLib.sol";
import "../../../../src/interfaces/ILiquidityGauge.sol";
import "../../../../src/interfaces/IERC20.sol";
import "../../../interfaces/IUSXTest.t.sol";
import "../../../interfaces/ITreasuryTest.t.sol";
import "../../../common/constants.t.sol";
import "./../../common/TestHelpers.t.sol";

contract TestPostSwapMint is Test, RedeemHelper {
    function test_mint_after_emergency_swap(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier < 1e7);

        /// @dev Allocate initial funds for test
        mintForTest(TEST_DAI, DAI_AMOUNT * amountMultiplier);

        uint256 preUsxTotalSupply = IUSXTest(address(usx_proxy)).totalSupply();
        // Excluding last index (3CRV)
        for (uint256 i; i < TEST_COINS.length - 1; i++) {
            /// @dev Expectations
            uint256 preStakedAmount = ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy));
            uint256 preExpectedTokenAmount = calculateRedeemAmount(i, preStakedAmount, TEST_COINS[i]);
            uint256 preUserBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);

            /// @dev Setup
            uint256 id = vm.snapshot();
            ITreasuryTest(address(treasury_proxy)).emergencySwapBacking(TEST_COINS[i]);

            /// @dev Pre-action Assertions
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), preUsxTotalSupply);
            assertEq(preUserBalanceUSX, preUsxTotalSupply);
            assertEq(ITreasuryTest(address(treasury_proxy)).backingToken(), TEST_COINS[i]);
            assertEq(ITreasuryTest(address(treasury_proxy)).backingSwapped(), true);
            assertEq(ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_3CRV).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_COINS[i]).balanceOf(address(treasury_proxy)), preExpectedTokenAmount);

            /// @dev Act
            deal(TEST_COINS[i], TEST_USER, TEST_AMOUNTS[i] * amountMultiplier);
            uint256 amount = TEST_AMOUNTS[i] * amountMultiplier;
            vm.startPrank(TEST_USER);
            SafeTransferLib.safeApprove(ERC20(TEST_COINS[i]), address(treasury_proxy), amount);
            ITreasuryTest(address(treasury_proxy)).mint(TEST_COINS[i], amount);

            /// @dev Post-action Assertions
            uint256 postUserBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
            uint256 mintedUSX = postUserBalanceUSX - preUserBalanceUSX;

            // Ensure the correct amount of USX was minted
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), preUsxTotalSupply + mintedUSX);
            assertEq(ITreasuryTest(address(treasury_proxy)).totalSupply(), preUsxTotalSupply + mintedUSX);

            // Ensure the user received USX
            assertEq(postUserBalanceUSX, preUserBalanceUSX + mintedUSX);

            // Ensure there is no 3CRV in the Treasury or liquidity gauge
            assertEq(ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_3CRV).balanceOf(address(treasury_proxy)), 0);

            // Ensure treasury backing amount was properly updated
            assertEq(IERC20(TEST_COINS[i]).balanceOf(address(treasury_proxy)), preExpectedTokenAmount + mintedUSX);

            /// @dev Revert blockchain state to before minting for next iteration
            vm.revertTo(id);
            vm.stopPrank();
        }
    }

    function testCannot_mint_after_emergency_swap_unsupported() public {
        // TODO: fill in here.
    }
}
