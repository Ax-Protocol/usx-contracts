// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./common/TestSetup.t.sol";
import "../common/Constants.t.sol";
import "../../../src/treasury/interfaces/IBaseRewardPool.sol";
import "../../../src/treasury/interfaces/ICvxMining.sol";
import "../../../src/common/interfaces/IERC20.sol";
import "../../../src/common/interfaces/IUSXAdmin.sol";
import "../../../src/treasury/interfaces/ITreasuryAdmin.sol";

contract RedeemTest is RedeemHelper {
    /// @dev Test that each supported token can be redeemed in a sequential manner, without resetting chain state after each mint
    function test_redeem_sequential(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier < 1e7);

        // Allocate funds for test
        _mintForTest(DAI, DAI_AMOUNT * 4 * amountMultiplier);

        // Setup
        uint256 usxInitialSupply = IUSXAdmin(address(usx_proxy)).totalSupply();
        uint256 usxTotalSupply = IUSXAdmin(address(usx_proxy)).totalSupply();
        uint256 stakedAmount = IBaseRewardPool(CVX3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy));
        uint256 treasuryBalanceCRV = IERC20(CRV).balanceOf(address(treasury_proxy));
        uint256 treasuryBalanceCVX = IERC20(CVX).balanceOf(address(treasury_proxy));

        for (uint256 i; i < TEST_COINS.length; i++) {
            // Expectations
            skip(ONE_WEEK);
            uint256 burnAmountUSX = usxInitialSupply / TEST_COINS.length;
            uint256 curveAmountUsed = _calculateCurveTokenAmount(burnAmountUSX);
            uint256 expectedRedeemAmount = _calculateRedeemAmount(i, curveAmountUsed, TEST_COINS[i]);
            uint256 expectedCrvRewardAmount = IBaseRewardPool(CVX3CRV_BASE_REWARD_POOL).earned(address(treasury_proxy));
            uint256 expectedCvxRewardAmount = ICvxMining(CVX_MINING).ConvertCrvToCvx(expectedCrvRewardAmount);

            vm.expectEmit(true, true, true, true, address(treasury_proxy));
            emit Redemption(TEST_USER, burnAmountUSX);

            // Setup
            vm.startPrank(TEST_USER);

            // Pre-action data extraction
            uint256 preUserBalanceUSX = IUSXAdmin(address(usx_proxy)).balanceOf(TEST_USER);

            // Pre-action assertions
            assertEq(preUserBalanceUSX, usxTotalSupply, "Equivalence violation: preUserBalanceUSX and usxTotalSupply.");

            // Act
            ITreasuryAdmin(address(treasury_proxy)).redeem(TEST_COINS[i], burnAmountUSX);

            /// @dev Post-action assertions
            // Ensure USX was burned
            assertEq(
                IUSXAdmin(address(usx_proxy)).totalSupply(),
                usxTotalSupply - burnAmountUSX,
                "Equivalence violation: post-action total supply (USX) and usxTotalSupply - burnAmountUSX."
            );
            assertEq(
                ITreasuryAdmin(address(treasury_proxy)).totalSupply(),
                usxTotalSupply - burnAmountUSX,
                "Equivalence violation: post-action total supply (Treasury) and usxTotalSupply - burnAmountUSX."
            );
            assertEq(
                IUSXAdmin(address(usx_proxy)).balanceOf(TEST_USER),
                usxTotalSupply - burnAmountUSX,
                "Equivalence violation: post-action user USX balance and usxTotalSupply - burnAmountUSX."
            );

            // Ensure the user received the desired output token
            assertEq(
                IERC20(TEST_COINS[i]).balanceOf(TEST_USER),
                expectedRedeemAmount,
                "Equivalence violation: user test coin balance and expectedRedeemAmount."
            );

            // Ensure cvx3CRV in CVX3CRV_BASE_REWARD_POOL properly decreased
            assertEq(
                IBaseRewardPool(CVX3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
                stakedAmount - curveAmountUsed,
                "Equivalence violation: treasury staked cvx3CRV balance and stakedAmount - curveAmountUsed."
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
        _mintForTest(DAI, DAI_AMOUNT * amountMultiplier);

        uint256 usxTotalSupply = IUSXAdmin(address(usx_proxy)).totalSupply();
        for (uint256 i; i < TEST_COINS.length; i++) {
            // Expectations
            uint256 curveAmountUsed = _calculateCurveTokenAmount(usxTotalSupply);
            uint256 expectedRedeemAmount = _calculateRedeemAmount(i, curveAmountUsed, TEST_COINS[i]);
            uint256 stakedAmount = IBaseRewardPool(CVX3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy));
            uint256 expectedCrvRewardAmount = IBaseRewardPool(CVX3CRV_BASE_REWARD_POOL).earned(address(treasury_proxy));
            uint256 expectedCvxRewardAmount = ICvxMining(CVX_MINING).ConvertCrvToCvx(expectedCrvRewardAmount);

            vm.expectEmit(true, true, true, true, address(treasury_proxy));
            emit Redemption(TEST_USER, usxTotalSupply);

            // Setup
            vm.startPrank(TEST_USER);

            // Pre-action data extraction
            uint256 preUserBalanceUSX = IUSXAdmin(address(usx_proxy)).balanceOf(TEST_USER);

            // Pre-action assertions
            assertEq(preUserBalanceUSX, usxTotalSupply, "Equivalence violation: preUserBalanceUSX and usxTotalSupply.");
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
            ITreasuryAdmin(address(treasury_proxy)).redeem(TEST_COINS[i], usxTotalSupply);

            /// @dev Post-action assertions
            // Ensure USX was burned
            assertEq(
                IUSXAdmin(address(usx_proxy)).totalSupply(),
                0,
                "Equivalence violation: post-action total supply (USX) is not zero."
            );
            assertEq(
                ITreasuryAdmin(address(treasury_proxy)).totalSupply(),
                0,
                "Equivalence violation: post-action total supply (Treasury) is not zero."
            );
            assertEq(
                IUSXAdmin(address(usx_proxy)).balanceOf(TEST_USER),
                0,
                "Equivalence violation: post-action user USX balance is not zero."
            );

            // Ensure the user received the desired output token
            uint256 userERC20Balance = IERC20(TEST_COINS[i]).balanceOf(TEST_USER);
            assertEq(
                userERC20Balance,
                expectedRedeemAmount,
                "Equivalence violation: userERC20Balance and expectedRedeemAmount."
            );

            // Ensure cvx3CRV in BaseRewardPool properly decreased
            assertEq(
                IBaseRewardPool(CVX3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
                stakedAmount - curveAmountUsed,
                "Equivalence violation: treasury staked cvx3CRV balance and stakedAmount - curveAmountUsed."
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
        ITreasuryAdmin(address(treasury_proxy)).redeem(unsupportedStable, TEST_MINT_AMOUNT);
    }

    function testFail_redeem_amount(uint256 burnAmount) public {
        vm.assume(burnAmount > TEST_MINT_AMOUNT);

        // Allocate funds for test
        vm.prank(address(treasury_proxy));
        IUSXAdmin(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        // Expectations
        vm.expectEmit(true, true, true, true, address(treasury_proxy));
        emit Redemption(address(this), burnAmount);

        // Pre-action assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            TEST_MINT_AMOUNT,
            "Equivalence violation: pre-action total supply and TEST_MINT_AMOUNT."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            TEST_MINT_AMOUNT,
            "Equivalence violation: pre-action treasury USX balance and TEST_MINT_AMOUNT."
        );

        // Act: burnAmount greater than amount minted
        ITreasuryAdmin(address(treasury_proxy)).redeem(DAI, burnAmount);
    }
}
