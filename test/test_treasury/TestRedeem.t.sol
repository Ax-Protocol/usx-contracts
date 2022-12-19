// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/interfaces/IBaseRewardPool.sol";
import "../../src/interfaces/IERC20.sol";
import "../interfaces/IUSXTest.t.sol";
import "../interfaces/ITreasuryTest.t.sol";
import "../interfaces/ICvxMining.t.sol";
import "../common/Constants.t.sol";
import "./common/TestHelpers.t.sol";

contract TestRedeem is Test, RedeemHelper {
    /// @dev Test that each supported token can be redeemed in a sequential manner, without resetting chain state after each mint
    function test_redeem_sequential(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier < 1e7);

        // Allocate funds for test
        mintForTest(DAI, DAI_AMOUNT * 4 * amountMultiplier);

        // Setup
        uint256 usxInitialSupply = IUSXTest(address(usx_proxy)).totalSupply();
        uint256 usxTotalSupply = IUSXTest(address(usx_proxy)).totalSupply();
        uint256 stakedAmount = IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy));
        uint256 treasuryBalanceCRV = IERC20(CRV).balanceOf(address(treasury_proxy));
        uint256 treasuryBalanceCVX = IERC20(CVX).balanceOf(address(treasury_proxy));

        for (uint256 i; i < TEST_COINS.length; i++) {
            // Expectations
            skip(ONE_WEEK);
            uint256 burnAmountUSX = usxInitialSupply / TEST_COINS.length;
            uint256 curveAmountUsed = calculateCurveTokenAmount(burnAmountUSX);
            uint256 expectedRedeemAmount = calculateRedeemAmount(i, curveAmountUsed, TEST_COINS[i]);
            uint256 expectedCrvRewardAmount = IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).earned(address(treasury_proxy));
            uint256 expectedCvxRewardAmount = ICvxMining(CVX_MINING).ConvertCrvToCvx(expectedCrvRewardAmount);

            vm.expectEmit(true, true, true, true, address(treasury_proxy));
            emit Redemption(TEST_USER, burnAmountUSX);

            // Setup
            vm.startPrank(TEST_USER);

            // Pre-action data extraction
            uint256 preUserBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);

            // Pre-action assertions
            assertEq(preUserBalanceUSX, usxTotalSupply, "Equivalence violation: preUserBalanceUSX and usxTotalSupply");

            // Act
            ITreasuryTest(address(treasury_proxy)).redeem(TEST_COINS[i], burnAmountUSX);

            /// @dev Post-action assertions
            // Ensure USX was burned
            assertEq(
                IUSXTest(address(usx_proxy)).totalSupply(),
                usxTotalSupply - burnAmountUSX,
                "Equivalence violation: post-action total supply (USX) and usxTotalSupply - burnAmountUSX"
            );
            assertEq(
                ITreasuryTest(address(treasury_proxy)).totalSupply(),
                usxTotalSupply - burnAmountUSX,
                "Equivalence violation: post-action total supply (Treasury) and usxTotalSupply - burnAmountUSX"
            );
            assertEq(
                IUSXTest(address(usx_proxy)).balanceOf(TEST_USER),
                usxTotalSupply - burnAmountUSX,
                "Equivalence violation: post-action user USX balance and usxTotalSupply - burnAmountUSX"
            );

            // Ensure the user received the desired output token
            assertEq(
                IERC20(TEST_COINS[i]).balanceOf(TEST_USER),
                expectedRedeemAmount,
                "Equivalence violation: user test coin balance and expectedRedeemAmount"
            );

            // Ensure cvx3CRV in CVX_3CRV_BASE_REWARD_POOL properly decreased
            assertEq(
                IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
                stakedAmount - curveAmountUsed,
                "Equivalence violation: treasury staked cvx3CRV balance and stakedAmount - curveAmountUsed"
            );

            // Ensure that treasury received CVR and CVX rewards
            assertEq(
                IERC20(CRV).balanceOf(address(treasury_proxy)),
                treasuryBalanceCRV + expectedCrvRewardAmount,
                "Equivalence violation: treasury CRV balance and treasuryBalanceCRV + expectedCrvRewardAmount."
            );
            assertEq(
                IERC20(CVX).balanceOf(address(treasury_proxy)),
                treasuryBalanceCVX + expectedCvxRewardAmount,
                "Equivalence violation: treasury CVX balance and treasuryBalanceCVX + expectedCvxRewardAmount."
            );

            usxTotalSupply -= burnAmountUSX;
            stakedAmount -= curveAmountUsed;
            treasuryBalanceCRV += expectedCrvRewardAmount;
            treasuryBalanceCVX += expectedCvxRewardAmount;
            vm.stopPrank();
        }
    }

    /// @dev Test that each supported token can be redeemed on its own, resetting chain state after each mint
    function test_redeem_independent(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier < 1e7);

        // Allocate funds for test
        mintForTest(DAI, DAI_AMOUNT * amountMultiplier);

        uint256 usxTotalSupply = IUSXTest(address(usx_proxy)).totalSupply();
        for (uint256 i; i < TEST_COINS.length; i++) {
            // Expectations
            uint256 curveAmountUsed = calculateCurveTokenAmount(usxTotalSupply);
            uint256 expectedRedeemAmount = calculateRedeemAmount(i, curveAmountUsed, TEST_COINS[i]);
            uint256 stakedAmount = IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy));
            uint256 expectedCrvRewardAmount = IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).earned(address(treasury_proxy));
            uint256 expectedCvxRewardAmount = ICvxMining(CVX_MINING).ConvertCrvToCvx(expectedCrvRewardAmount);

            vm.expectEmit(true, true, true, true, address(treasury_proxy));
            emit Redemption(TEST_USER, usxTotalSupply);

            // Setup
            vm.startPrank(TEST_USER);

            // Pre-action data extraction
            uint256 preUserBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);

            // Pre-action assertions
            assertEq(preUserBalanceUSX, usxTotalSupply, "Equivalence violation: preUserBalanceUSX and usxTotalSupply");
            assertEq(
                IERC20(CRV).balanceOf(address(treasury_proxy)),
                0,
                "Equivalence violation: treasury CRV balance is not zero."
            );
            assertEq(
                IERC20(CVX).balanceOf(address(treasury_proxy)),
                0,
                "Equivalence violation: treasury CVX balance is not zero."
            );

            // Act
            uint256 id = vm.snapshot();
            ITreasuryTest(address(treasury_proxy)).redeem(TEST_COINS[i], usxTotalSupply);

            /// @dev Post-action assertions
            // Ensure USX was burned
            assertEq(
                IUSXTest(address(usx_proxy)).totalSupply(),
                0,
                "Equivalence violation: post-action total supply (USX) is not zero"
            );
            assertEq(
                ITreasuryTest(address(treasury_proxy)).totalSupply(),
                0,
                "Equivalence violation: post-action total supply (Treasury) is not zero"
            );
            assertEq(
                IUSXTest(address(usx_proxy)).balanceOf(TEST_USER),
                0,
                "Equivalence violation: post-action user USX balance is not zero"
            );

            // Ensure the user received the desired output token
            uint256 userERC20Balance = IERC20(TEST_COINS[i]).balanceOf(TEST_USER);
            assertEq(
                userERC20Balance,
                expectedRedeemAmount,
                "Equivalence violation: userERC20Balance and expectedRedeemAmount"
            );

            // Ensure cvx3CRV in BaseRewardPool properly decreased
            assertEq(
                IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
                stakedAmount - curveAmountUsed,
                "Equivalence violation: treasury staked cvx3CRV balance and stakedAmount - curveAmountUsed"
            );

            // Ensure that treasury received CVR and CVX rewards
            assertEq(
                IERC20(CRV).balanceOf(address(treasury_proxy)),
                expectedCrvRewardAmount,
                "Equivalence violation: treasury CRV balance and expectedCrvRewardAmount."
            );
            assertEq(
                IERC20(CVX).balanceOf(address(treasury_proxy)),
                expectedCvxRewardAmount,
                "Equivalence violation: treasury CVX balance and expectedCvxRewardAmount."
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

        // Expectations
        vm.expectEmit(true, true, true, true, address(treasury_proxy));
        emit Redemption(address(this), burnAmount);

        // Pre-action assertions
        assertEq(
            IUSXTest(address(usx_proxy)).totalSupply(),
            TEST_MINT_AMOUNT,
            "Equivalence violation: pre-action total supply and TEST_MINT_AMOUNT"
        );
        assertEq(
            IUSXTest(address(usx_proxy)).balanceOf(address(this)),
            TEST_MINT_AMOUNT,
            "Equivalence violation: pre-action treasury USX balance and TEST_MINT_AMOUNT"
        );

        // Act: burnAmount greater than amount minted
        ITreasuryTest(address(treasury_proxy)).redeem(DAI, burnAmount);
    }
}
