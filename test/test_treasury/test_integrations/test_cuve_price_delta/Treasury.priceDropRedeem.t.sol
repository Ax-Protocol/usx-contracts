// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "./../../common/TestSetup.t.sol";

import "../../../../src/treasury/interfaces/ICurve3Pool.sol";
import "../../../../src/common/interfaces/IERC20.sol";
import "../../../../src/treasury/interfaces/ITreasuryAdmin.sol";

import "../../../common/Constants.t.sol";

contract PriceDropRedeemTest is Test, RedeemHelper {
    function test_redeem_negative_price_delta(uint256 priceDelta) public {
        // Assumptions
        vm.assume(priceDelta > 0 && priceDelta <= _3CRV_VIRTUAL_PRICE);

        /// @dev Allocate funds for test
        _mintForTestCurveMocked(DAI, DAI_AMOUNT);
        uint256 usxMinted = IERC20(address(usx_proxy)).balanceOf(TEST_USER);
        uint256 usxBurnAmount = usxMinted / 3;

        /// @dev Iteration 1, with a higher 3CRV price

        // Mock Curve 1
        vm.mockCall(
            STABLE_SWAP_3POOL,
            abi.encodeWithSelector(ICurve3Pool(STABLE_SWAP_3POOL).get_virtual_price.selector),
            abi.encode(_3CRV_VIRTUAL_PRICE)
        );

        // Expectations 1
        uint256 curveAmountUsed1 = _calculateCurveTokenAmount(usxBurnAmount);
        uint256 expectedRedeemAmount1 = _calculateRedeemAmount(0, curveAmountUsed1, DAI);

        // Pre-action assertions 1
        uint256 initialUserBalance1 = IERC20(DAI).balanceOf(TEST_USER);
        assertEq(initialUserBalance1, 0, "Equivalence violation: initialUserBalance1 is not zero");

        // Act 1
        vm.prank(TEST_USER);
        ITreasuryAdmin(address(treasury_proxy)).redeem(DAI, usxBurnAmount);

        // Post-action 1 assertions
        uint256 postUserBalance1 = IERC20(DAI).balanceOf(TEST_USER);
        uint256 redeemedAmount1 = postUserBalance1 - initialUserBalance1;
        // Ensure that previousLpTokenPrice is set
        assertEq(
            ITreasuryAdmin(address(treasury_proxy)).previousLpTokenPrice(),
            _3CRV_VIRTUAL_PRICE,
            "Equivalence violation: previous 3RCV price and _3CRV_VIRTUAL_PRICE"
        );

        // Ensure redemption matches expectation (higher price)
        assertEq(
            redeemedAmount1, expectedRedeemAmount1, "Equivalence violation: redeemedAmount1 and expectedRedeemAmount1"
        );

        /// @dev Iteration 2, with a lower 3CRV price

        // Expectations 1: calculate expectation before lowering 3CRV price, as it shouldn't decrease
        uint256 curveAmountUsed2 = _calculateCurveTokenAmount(usxBurnAmount);
        uint256 expectedRedeemAmount2 = _calculateRedeemAmount(0, curveAmountUsed2, DAI);

        // Mock Curve 2
        vm.mockCall(
            STABLE_SWAP_3POOL,
            abi.encodeWithSelector(ICurve3Pool(STABLE_SWAP_3POOL).get_virtual_price.selector),
            abi.encode(_3CRV_VIRTUAL_PRICE - priceDelta)
        );

        // Act 2
        vm.prank(TEST_USER);
        ITreasuryAdmin(address(treasury_proxy)).redeem(DAI, usxBurnAmount);

        // Post-action 2 assertions
        uint256 postUserBalance2 = IERC20(DAI).balanceOf(TEST_USER);
        uint256 redeemedAmount2 = postUserBalance2 - postUserBalance1;
        // Ensure that conversion price remains at the higher 3CRV price
        assertEq(
            ITreasuryAdmin(address(treasury_proxy)).previousLpTokenPrice(),
            _3CRV_VIRTUAL_PRICE,
            "Equivalence violation: previous 3RCV price and _3CRV_VIRTUAL_PRICE"
        );
        // Ensure redemption matches expectation (using higher price)
        assertEq(
            redeemedAmount2, expectedRedeemAmount2, "Equivalence violation: redeemedAmount2 and expectedRedeemAmount2"
        );
    }
}
