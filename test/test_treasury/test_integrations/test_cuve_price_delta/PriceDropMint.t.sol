// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "solmate/utils/SafeTransferLib.sol";
import "./../../common/TestHelpers.t.sol";

import "../../../../src/treasury/interfaces/ICurve3Pool.sol";
import "../../../../src/common/interfaces/IUSXAdmin.sol";
import "../../../../src/treasury/interfaces/ITreasuryAdmin.sol";

import "../../../common/Constants.t.sol";

contract PriceDropMintTest is Test, MintHelper {
    /// @dev Test that mint works using a previously higher 3CRV conversion factor
    function test_mint_negative_price_delta(uint256 priceDelta) public {
        // Assumptions
        vm.assume(priceDelta <= _3CRV_VIRTUAL_PRICE);
        vm.startPrank(TEST_USER);

        uint256 testDepositAmount = TEST_DEPOSIT_AMOUNT / 2;

        // Allocate funds for test
        deal(DAI, TEST_USER, TEST_DEPOSIT_AMOUNT);

        /// @dev Iteration 1, with a higher 3CRV price
        // Mock Curve 1, setting the 3CRV price
        vm.mockCall(
            STABLE_SWAP_3POOL,
            abi.encodeWithSelector(ICurve3Pool(STABLE_SWAP_3POOL).get_virtual_price.selector),
            abi.encode(_3CRV_VIRTUAL_PRICE)
        );

        // Expectations 1
        (uint256 expectedMintAmount1,) = _calculateMintAmount(0, testDepositAmount, DAI);
        uint256 preUserBalanceUSX = IUSXAdmin(address(usx_proxy)).balanceOf(TEST_USER);
        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(), 0, "Equivalence violation: pre-action total supply is not zero"
        );
        assertEq(preUserBalanceUSX, 0, "Equivalence violation: preUserBalanceUSX is not zero");

        // Act 1
        SafeTransferLib.safeApprove(ERC20(DAI), address(treasury_proxy), testDepositAmount);
        ITreasuryAdmin(address(treasury_proxy)).mint(DAI, testDepositAmount);

        // Post-action data extraction 1
        uint256 postUserBalanceUSX1 = IUSXAdmin(address(usx_proxy)).balanceOf(TEST_USER);
        uint256 mintedUSX1 = postUserBalanceUSX1 - preUserBalanceUSX;
        // Ensure that conversion price was set
        assertEq(
            ITreasuryAdmin(address(treasury_proxy)).previousLpTokenPrice(),
            _3CRV_VIRTUAL_PRICE,
            "Equivalence violation: previous 3CRV price and _3CRV_VIRTUAL_PRICE"
        );
        // Ensure that the amount of USX minted matches expectation (using higher price)
        assertEq(mintedUSX1, expectedMintAmount1, "Equivalence violation: mintedUSX1 and expectedMintAmount1");

        /// @dev Iteration 2, with a lower 3CRV price
        // Expectations 2: calculate expectation before lowering 3CRV price, as it shouldn't decrease
        (uint256 expectedMintAmount2,) = _calculateMintAmount(0, testDepositAmount, DAI);

        // Mock Curve 2, lowering the 3CRV price
        vm.mockCall(
            STABLE_SWAP_3POOL,
            abi.encodeWithSelector(ICurve3Pool(STABLE_SWAP_3POOL).get_virtual_price.selector),
            abi.encode(_3CRV_VIRTUAL_PRICE - priceDelta)
        );

        // Act 2
        SafeTransferLib.safeApprove(ERC20(DAI), address(treasury_proxy), testDepositAmount);
        ITreasuryAdmin(address(treasury_proxy)).mint(DAI, testDepositAmount);

        // Post-action assertions 2
        uint256 postUserBalanceUSX2 = IUSXAdmin(address(usx_proxy)).balanceOf(TEST_USER);
        uint256 mintedUSX2 = postUserBalanceUSX2 - postUserBalanceUSX1;
        // Ensure that conversion price remains at the higher 3CRV price
        assertEq(
            ITreasuryAdmin(address(treasury_proxy)).previousLpTokenPrice(),
            _3CRV_VIRTUAL_PRICE,
            "Equivalence violation: previous 3RCV price and _3CRV_VIRTUAL_PRICE"
        );
        // Ensure that the amount of USX minted matches expectation (using higher price)
        assertEq(mintedUSX2, expectedMintAmount2, "Equivalence violation: mintedUSX2 and expectedMintAmount2");

        vm.stopPrank();
    }
}
