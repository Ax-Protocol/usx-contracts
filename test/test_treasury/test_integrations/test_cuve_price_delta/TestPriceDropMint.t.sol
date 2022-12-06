// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "solmate/utils/SafeTransferLib.sol";
import "../../../../src/interfaces/IStableSwap3Pool.sol";
import "../../../interfaces/IUSXTest.t.sol";
import "../../../interfaces/ITreasuryTest.t.sol";
import "../../../common/constants.t.sol";
import "./../../common/TestHelpers.t.sol";

contract TestPriceDropMint is Test, MintHelper {
    /// @dev Test that mint works using a previously higher 3CRV conversion factor
    function test_mint_negative_price_delta(uint256 priceDelta) public {
        // Assumptions
        vm.assume(priceDelta <= TEST_3CRV_VIRTUAL_PRICE);
        vm.startPrank(TEST_USER);

        uint256 testDepositAmount = TEST_DEPOSIT_AMOUNT / 2;

        // Allocate funds for test
        deal(TEST_DAI, TEST_USER, TEST_DEPOSIT_AMOUNT);

        /// @dev Iteration 1, with a higher 3CRV price
        // Mock Curve 1, setting the 3CRV price
        vm.mockCall(
            TEST_STABLE_SWAP_3POOL,
            abi.encodeWithSelector(IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).get_virtual_price.selector),
            abi.encode(TEST_3CRV_VIRTUAL_PRICE)
        );

        // Expectations 1
        (uint256 expectedMintAmount1,) = calculateMintAmount(0, testDepositAmount, TEST_DAI);
        uint256 preUserBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), 0);
        assertEq(preUserBalanceUSX, 0);

        // Act 1
        SafeTransferLib.safeApprove(ERC20(TEST_DAI), address(treasury_proxy), testDepositAmount);
        ITreasuryTest(address(treasury_proxy)).mint(TEST_DAI, testDepositAmount);

        // Post-action data extraction 1
        uint256 postUserBalanceUSX1 = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
        uint256 mintedUSX1 = postUserBalanceUSX1 - preUserBalanceUSX;
        // Ensure that conversion price was set
        assertEq(ITreasuryTest(address(treasury_proxy)).previousLpTokenPrice(), TEST_3CRV_VIRTUAL_PRICE);
        // Ensure that the amount of USX minted matches expectation (using higher price)
        assertEq(mintedUSX1, expectedMintAmount1);

        /// @dev Iteration 2, with a lower 3CRV price
        // Expectations 2: calculate expectation before lowering 3CRV price, as it shouldn't decrease
        (uint256 expectedMintAmount2,) = calculateMintAmount(0, testDepositAmount, TEST_DAI);

        // Mock Curve 2, lowering the 3CRV price
        vm.mockCall(
            TEST_STABLE_SWAP_3POOL,
            abi.encodeWithSelector(IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).get_virtual_price.selector),
            abi.encode(TEST_3CRV_VIRTUAL_PRICE - priceDelta)
        );

        // Act 2
        SafeTransferLib.safeApprove(ERC20(TEST_DAI), address(treasury_proxy), testDepositAmount);
        ITreasuryTest(address(treasury_proxy)).mint(TEST_DAI, testDepositAmount);

        // Post-action assertions 2
        uint256 postUserBalanceUSX2 = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
        uint256 mintedUSX2 = postUserBalanceUSX2 - postUserBalanceUSX1;
        // Ensure that conversion price remains at the higher 3CRV price
        assertEq(ITreasuryTest(address(treasury_proxy)).previousLpTokenPrice(), TEST_3CRV_VIRTUAL_PRICE);
        // Ensure that the amount of USX minted matches expectation (using higher price)
        assertEq(mintedUSX2, expectedMintAmount2);

        vm.stopPrank();
    }
}
