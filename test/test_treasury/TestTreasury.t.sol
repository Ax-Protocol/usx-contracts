// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "solmate/utils/SafeTransferLib.sol";
import "../../src/Treasury.sol";
import "../../src/USX.sol";
import "../../src/proxy/ERC1967Proxy.sol";
import "../../src/interfaces/IStableSwap3Pool.sol";
import "../../src/interfaces/ILiquidityGauge.sol";
import "../../src/interfaces/IERC20.sol";
import "../interfaces/IUSXTest.t.sol";
import "../interfaces/ITreasuryTest.t.sol";
import "../mocks/MockStableSwap3Pool.t.sol";
import "../common/constants.t.sol";

import "forge-std/console.sol";

abstract contract SharedSetup is Test {
    // Test Contracts
    Treasury public treasury_implementation;
    USX public usx_implementation;
    ERC1967Proxy public treasury_proxy;
    ERC1967Proxy public usx_proxy;

    // Test Constants
    address constant TEST_STABLE_SWAP_3POOL = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7; // Ethereum
    address constant TEST_LIQUIDITY_GAUGE = 0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A; // Ethereum
    address constant TEST_DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // Ethereum
    address constant TEST_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // Ethereum
    address constant TEST_USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // Ethereum
    address constant TEST_STABLE = 0xaD37Cd49a9dd24BE734212AEFA1b862ead92eEF2;
    address constant TEST_USER = 0x19Bb08638DD185b7455ffD1bB96765108B0aB556;
    address[4] TEST_COINS = [TEST_DAI, TEST_USDC, TEST_USDT, TEST_3CRV];

    uint256 constant DAI_AMOUNT = 1e18;
    uint256 constant USDC_AMOUNT = 1e6;
    uint256 constant USDT_AMOUNT = 1e6;
    uint256 constant CURVE_AMOUNT = 1e18;
    uint256 constant USX_AMOUNT = 1e18;
    uint256[4] TEST_AMOUNTS = [DAI_AMOUNT, USDC_AMOUNT, USDT_AMOUNT, CURVE_AMOUNT];

    // Events
    event Mint(address indexed account, uint256 amount);
    event Redemption(address indexed account, uint256 amount);

    function setUp() public {
        // Deploy USX implementation, and link to proxy
        usx_implementation = new USX();
        usx_proxy =
            new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize(address)", LZ_ENDPOINT));

        // Deploy Treasury implementation, and link to proxy
        treasury_implementation = new Treasury();
        treasury_proxy =
        new ERC1967Proxy(address(treasury_implementation), abi.encodeWithSignature("initialize(address,address,address,address)", TEST_STABLE_SWAP_3POOL, TEST_LIQUIDITY_GAUGE, address(usx_proxy), TEST_3CRV));

        // Set treasury admin on token contract
        IUSXTest(address(usx_proxy)).manageTreasuries(address(treasury_proxy), true, true);

        // Set supported stable coins on treasury contract
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_DAI, 0);
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_USDC, 1);
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_USDT, 2);
    }
}

contract TestMint is Test, SharedSetup {
    function calculateMintAmount(uint256 index, uint256 amount, address coin)
        private
        returns (uint256 mintAmount, uint256 lpTokens)
    {
        // Take snapshot before calculation
        uint256 id = vm.snapshot();

        // Add liquidity
        if (coin != TEST_3CRV) {
            SafeTransferLib.safeApprove(ERC20(coin), TEST_STABLE_SWAP_3POOL, amount);
            uint256[3] memory amounts;
            amounts[index] = amount;
            uint256 preBalance = IERC20(TEST_3CRV).balanceOf(TEST_USER);
            IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).add_liquidity(amounts, 0);
            uint256 postBalance = IERC20(TEST_3CRV).balanceOf(TEST_USER);
            lpTokens = postBalance - preBalance;
        } else {
            lpTokens = amount;
        }

        // Obtain 3CRV price
        uint256 lpTokenPrice = IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).get_virtual_price();

        // Revert to blockchain state before Curve interaction
        vm.revertTo(id);

        // Return expected mint amount
        mintAmount = (lpTokens * lpTokenPrice) / 1e18;
    }

    /// @dev Test that each coin can be minted in a sequential manner, not resetting chain state after each mint
    function test_mint_sequential(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier < 1e11);
        /// @dev Allocate funds for test
        deal(TEST_DAI, TEST_USER, DAI_AMOUNT * amountMultiplier);
        deal(TEST_USDC, TEST_USER, USDC_AMOUNT * amountMultiplier);
        deal(TEST_USDT, TEST_USER, USDT_AMOUNT * amountMultiplier);
        deal(TEST_3CRV, TEST_USER, CURVE_AMOUNT * amountMultiplier);

        vm.startPrank(TEST_USER);

        uint256 totalMinted;
        uint256 totalStaked;
        for (uint256 i; i < TEST_COINS.length; i++) {
            /// @dev Setup
            uint256 amount = TEST_AMOUNTS[i] * amountMultiplier;

            // Expectations
            (uint256 expectedMintAmount, uint256 lpTokens) = calculateMintAmount(i, amount, TEST_COINS[i]);
            vm.expectEmit(true, true, true, true, address(treasury_proxy));
            emit Mint(TEST_USER, expectedMintAmount);

            // Pre-action Assertions
            uint256 preUserBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), totalMinted);
            assertEq(preUserBalanceUSX, totalMinted);

            // Act
            SafeTransferLib.safeApprove(ERC20(TEST_COINS[i]), address(treasury_proxy), amount);
            ITreasuryTest(address(treasury_proxy)).mint(TEST_COINS[i], amount);

            // Post-action Assertions
            uint256 postUserBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
            uint256 mintedUSX = postUserBalanceUSX - preUserBalanceUSX;

            // Ensure the correct amount of USX was minted
            assertEq(mintedUSX, expectedMintAmount);
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), totalMinted + mintedUSX);
            assertEq(ITreasuryTest(address(treasury_proxy)).totalSupply(), totalMinted + mintedUSX);

            // Ensure the user received USX
            assertEq(postUserBalanceUSX, totalMinted + mintedUSX);

            // Ensure the stable coins were taken from the user
            assertEq(IERC20(TEST_COINS[i]).balanceOf(TEST_USER), 0);

            // Ensure that the liquidity gauge received tokens
            assertEq(ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy)), totalStaked + lpTokens);

            totalMinted += mintedUSX;
            totalStaked += lpTokens;
        }
        vm.stopPrank();
    }

    /// @dev Test that each coin can be minted on its own, resetting chain state after each mint
    function test_mint_independent(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier < 1e11);

        /// @dev Allocate funds for test
        deal(TEST_DAI, TEST_USER, DAI_AMOUNT * amountMultiplier);
        deal(TEST_USDC, TEST_USER, USDC_AMOUNT * amountMultiplier);
        deal(TEST_USDT, TEST_USER, USDT_AMOUNT * amountMultiplier);
        deal(TEST_3CRV, TEST_USER, CURVE_AMOUNT * amountMultiplier);

        vm.startPrank(TEST_USER);

        for (uint256 i; i < TEST_COINS.length; i++) {
            /// @dev Setup
            uint256 amount = TEST_AMOUNTS[i] * amountMultiplier;

            /// @dev Expectations
            (uint256 expectedMintAmount, uint256 lpTokens) = calculateMintAmount(i, amount, TEST_COINS[i]);
            vm.expectEmit(true, true, true, true, address(treasury_proxy));
            emit Mint(TEST_USER, expectedMintAmount);

            /// @dev Pre-action Assertions
            uint256 preUserBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), 0);
            assertEq(preUserBalanceUSX, 0);

            /// @dev Act
            uint256 id = vm.snapshot();
            SafeTransferLib.safeApprove(ERC20(TEST_COINS[i]), address(treasury_proxy), amount);
            ITreasuryTest(address(treasury_proxy)).mint(TEST_COINS[i], amount);

            /// @dev Post-action Assertions
            uint256 postUserBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
            uint256 mintedUSX = postUserBalanceUSX - preUserBalanceUSX;

            // Ensure the correct amount of USX was minted
            assertEq(mintedUSX, expectedMintAmount);
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), mintedUSX);
            assertEq(ITreasuryTest(address(treasury_proxy)).totalSupply(), mintedUSX);

            // Ensure the user received USX
            assertEq(postUserBalanceUSX, mintedUSX);

            // Ensure the stable coins were taken from the user
            assertEq(IERC20(TEST_COINS[i]).balanceOf(TEST_USER), 0);

            // Ensure that the liquidity gauge received tokens
            assertEq(ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy)), lpTokens);

            /// @dev Revert blockchain state to before USX was minted for next iteration
            vm.revertTo(id);
            vm.stopPrank();
        }
    }

    /// @dev Test that we mint using the previous, higher conversion factor
    function test_mint_negative_price_delta(uint256 priceDelta) public {
        /// @dev Assumptions
        vm.assume(priceDelta <= TEST_3CRV_VIRTUAL_PRICE);
        vm.startPrank(TEST_USER);

        uint256 testDepositAmount = TEST_DEPOSIT_AMOUNT / 2;

        /// @dev Allocate funds for test
        deal(TEST_DAI, TEST_USER, TEST_DEPOSIT_AMOUNT);

        /* ****************************************************************************
        **
        **  Iteration 1, with a higher 3CRV price
        **
        ******************************************************************************/

        /// @dev Mock Curve 1, setting the 3CRV price
        vm.mockCall(
            TEST_STABLE_SWAP_3POOL,
            abi.encodeWithSelector(IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).get_virtual_price.selector),
            abi.encode(TEST_3CRV_VIRTUAL_PRICE)
        );

        /// @dev Expectations 1
        (uint256 expectedMintAmount1,) = calculateMintAmount(0, testDepositAmount, TEST_DAI);
        uint256 preUserBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), 0);
        assertEq(preUserBalanceUSX, 0);

        /// @dev Act 1
        SafeTransferLib.safeApprove(ERC20(TEST_DAI), address(treasury_proxy), testDepositAmount);
        ITreasuryTest(address(treasury_proxy)).mint(TEST_DAI, testDepositAmount);

        /// @dev Post-action data extraction 1
        uint256 postUserBalanceUSX1 = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
        uint256 mintedUSX1 = postUserBalanceUSX1 - preUserBalanceUSX;
        // Ensure that conversion price was set
        assertEq(ITreasuryTest(address(treasury_proxy)).previousLpTokenPrice(), TEST_3CRV_VIRTUAL_PRICE);
        // Ensure that the amount of USX minted matches expectation (using higher price)
        assertEq(mintedUSX1, expectedMintAmount1);

        /* ****************************************************************************
        **
        **  Iteration 2, with a lower 3CRV price
        **
        ******************************************************************************/

        /// @dev Expectations 2: calculate expectation before lowering 3CRV price, as it shouldn't decrease
        (uint256 expectedMintAmount2,) = calculateMintAmount(0, testDepositAmount, TEST_DAI);

        /// @dev Mock Curve 2, lowering the 3CRV price
        vm.mockCall(
            TEST_STABLE_SWAP_3POOL,
            abi.encodeWithSelector(IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).get_virtual_price.selector),
            abi.encode(TEST_3CRV_VIRTUAL_PRICE - priceDelta)
        );

        /// @dev Act 2
        SafeTransferLib.safeApprove(ERC20(TEST_DAI), address(treasury_proxy), testDepositAmount);
        ITreasuryTest(address(treasury_proxy)).mint(TEST_DAI, testDepositAmount);

        /// @dev Post-action Assertions 2
        uint256 postUserBalanceUSX2 = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
        uint256 mintedUSX2 = postUserBalanceUSX2 - postUserBalanceUSX1;
        // Ensure that conversion price remains at the higher 3CRV price
        assertEq(ITreasuryTest(address(treasury_proxy)).previousLpTokenPrice(), TEST_3CRV_VIRTUAL_PRICE);
        // Ensure that the amount of USX minted matches expectation (using higher price)
        assertEq(mintedUSX2, expectedMintAmount2);

        vm.stopPrank();
    }

    function test_fail_treasury_mint_unsupported_stable() public {
        // Test Variables
        address unsupportedStable = address(0);

        // Expectations
        vm.expectRevert("Unsupported stable.");

        // Act
        ITreasuryTest(address(treasury_proxy)).mint(unsupportedStable, TEST_MINT_AMOUNT);
    }
}

contract RedeemHelper is Test, SharedSetup {
    function mintForTest(address _tokenAddress, uint256 _amount) public {
        vm.startPrank(TEST_USER);
        deal(_tokenAddress, TEST_USER, _amount);
        IERC20(_tokenAddress).approve(address(treasury_proxy), _amount);
        ITreasuryTest(address(treasury_proxy)).mint(_tokenAddress, _amount);
        vm.stopPrank();
    }

    function calculateRedeemAmount(uint256 index, uint256 lpTokens, address coin)
        public
        returns (uint256 redeemAmount)
    {
        // Take snapshot before calculation
        uint256 id = vm.snapshot();

        if (coin != TEST_3CRV) {
            vm.startPrank(address(treasury_proxy));
            // Unstake 3CRV
            ILiquidityGauge(TEST_LIQUIDITY_GAUGE).withdraw(lpTokens);

            // Obtain contract's withdraw token balance before adding removing liquidity
            uint256 preBalance = IERC20(coin).balanceOf(address(treasury_proxy));

            // Remove liquidity from Curve
            IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).remove_liquidity_one_coin(lpTokens, int128(uint128(index)), 0);

            // Calculate the amount of stablecoin received from removing liquidity
            redeemAmount = IERC20(coin).balanceOf(address(treasury_proxy)) - preBalance;
            vm.stopPrank();
        } else {
            redeemAmount = lpTokens;
        }

        // Revert to blockchain state before Curve interaction
        vm.revertTo(id);
    }

    function calculateCurveTokenAmount(uint256 usxAmount) public returns (uint256) {
        uint256 lpTokenPrice = IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).get_virtual_price();
        uint256 conversionFactor = (1e18 * 1e18 / lpTokenPrice);
        return (usxAmount * conversionFactor) / 1e18;
    }
}

contract TestRedeem is Test, SharedSetup, RedeemHelper {
    /// @dev Test that each coin can be redeemed in a sequential manner, not resetting chain state after each mint
    function test_redeem_sequential(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier < 1e7);

        /// @dev Allocate funds for test
        mintForTest(TEST_DAI, DAI_AMOUNT * 4 * amountMultiplier);

        uint256 usxInitialSupply = IUSXTest(address(usx_proxy)).totalSupply();
        uint256 usxTotalSupply = IUSXTest(address(usx_proxy)).totalSupply();
        uint256 stakedAmount = ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy));
        for (uint256 i; i < TEST_COINS.length; i++) {
            /// @dev Expectations
            uint256 burnAmountUSX = usxInitialSupply / TEST_COINS.length;
            uint256 curveAmountUsed = calculateCurveTokenAmount(burnAmountUSX);
            uint256 expectedRedeemAmount = calculateRedeemAmount(i, curveAmountUsed, TEST_COINS[i]);

            vm.expectEmit(true, true, true, true, address(treasury_proxy));
            emit Redemption(TEST_USER, burnAmountUSX);

            /// @dev Setup
            vm.startPrank(TEST_USER);

            /// @dev Pre-action Assertions
            uint256 preUserBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), usxTotalSupply);
            assertEq(preUserBalanceUSX, usxTotalSupply);

            /// @dev Act
            ITreasuryTest(address(treasury_proxy)).redeem(TEST_COINS[i], burnAmountUSX);

            /// @dev Post-action Assertions
            // Ensure USX was burned
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), usxTotalSupply - burnAmountUSX);
            assertEq(IUSXTest(address(usx_proxy)).balanceOf(TEST_USER), usxTotalSupply - burnAmountUSX);
            assertEq(ITreasuryTest(address(treasury_proxy)).totalSupply(), usxTotalSupply - burnAmountUSX);

            // Ensure the user received the desired output token
            uint256 userERC20Balance = IERC20(TEST_COINS[i]).balanceOf(TEST_USER);
            assertEq(userERC20Balance, expectedRedeemAmount);

            // Ensure that LP tokens in liquidity gauge properly decreased
            assertEq(
                ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy)), stakedAmount - curveAmountUsed
            );

            usxTotalSupply -= burnAmountUSX;
            stakedAmount -= curveAmountUsed;
            vm.stopPrank();
        }
    }

    /// @dev Test that each coin can be redeemed on its own, resetting chain state after each mint
    function test_redeem_independent(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier < 1e7);

        /// @dev Allocate funds for test
        mintForTest(TEST_DAI, DAI_AMOUNT * amountMultiplier);

        uint256 usxTotalSupply = IUSXTest(address(usx_proxy)).totalSupply();
        for (uint256 i; i < TEST_COINS.length; i++) {
            /// @dev Expectations
            uint256 curveAmountUsed = calculateCurveTokenAmount(usxTotalSupply);
            uint256 expectedRedeemAmount = calculateRedeemAmount(i, curveAmountUsed, TEST_COINS[i]);
            uint256 stakedAmount = ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy));

            vm.expectEmit(true, true, true, true, address(treasury_proxy));
            emit Redemption(TEST_USER, usxTotalSupply);

            /// @dev Setup
            vm.startPrank(TEST_USER);

            /// @dev Pre-action Assertions
            uint256 preUserBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), usxTotalSupply);
            assertEq(preUserBalanceUSX, usxTotalSupply);

            /// @dev Act
            uint256 id = vm.snapshot();
            ITreasuryTest(address(treasury_proxy)).redeem(TEST_COINS[i], usxTotalSupply);

            /// @dev Post-action Assertions
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

    function test_redeem_negative_price_delta(uint256 priceDelta) public {
        /// @dev Assumptions
        vm.assume(priceDelta <= TEST_3CRV_VIRTUAL_PRICE);

        /// @dev Allocate funds for test
        // Give user USX
        vm.prank(address(treasury_proxy));
        IUSXTest(address(usx_proxy)).mint(TEST_USER, USX_AMOUNT);
        uint256 usxBurnAmount = USX_AMOUNT / 3;

        // Give Treasury 3CRV
        uint256 curveAmount = calculateCurveTokenAmount(USX_AMOUNT);
        deal(TEST_3CRV, address(treasury_proxy), curveAmount);

        /* ****************************************************************************
        **
        **  Iteration 1, with a higher 3CRV price
        **
        ******************************************************************************/

        /// @dev Mock Curve 1
        vm.mockCall(
            TEST_STABLE_SWAP_3POOL,
            abi.encodeWithSelector(IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).get_virtual_price.selector),
            abi.encode(TEST_3CRV_VIRTUAL_PRICE)
        );

        // Expectations 1
        uint256 curveAmountUsed1 = calculateCurveTokenAmount(usxBurnAmount);
        uint256 expectedRedeemAmount1 = calculateRedeemAmount(0, curveAmountUsed1, TEST_DAI);

        /// @dev Pre-action assertions 1
        uint256 initialUserBalance1 = IERC20(TEST_DAI).balanceOf(TEST_USER);
        assertEq(initialUserBalance1, 0);

        /// @dev Act 1
        vm.prank(TEST_USER);
        ITreasuryTest(address(treasury_proxy)).redeem(TEST_DAI, usxBurnAmount);

        /// @dev Post-action 1 assertions
        uint256 postUserBalance1 = IERC20(TEST_DAI).balanceOf(TEST_USER);
        uint256 redeemedAmount1 = postUserBalance1 - initialUserBalance1;
        // Ensure that previousLpTokenPrice is set
        assertEq(ITreasuryTest(address(treasury_proxy)).previousLpTokenPrice(), TEST_3CRV_VIRTUAL_PRICE);
        // Ensure redemption matches expectation (using higher price)
        assertEq(redeemedAmount1, expectedRedeemAmount1);

        /* ****************************************************************************
        **
        **  Iteration 2, with a lower 3CRV price
        **
        ******************************************************************************/

        /// @dev Expectations 1: calculate expectation before lowering 3CRV price, as it shouldn't decrease
        uint256 curveAmountUsed2 = calculateCurveTokenAmount(usxBurnAmount);
        uint256 expectedRedeemAmount2 = calculateRedeemAmount(0, curveAmountUsed2, TEST_DAI);

        /// @dev Mock Curve 2
        vm.mockCall(
            TEST_STABLE_SWAP_3POOL,
            abi.encodeWithSelector(IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).get_virtual_price.selector),
            abi.encode(TEST_3CRV_VIRTUAL_PRICE - priceDelta)
        );

        /// @dev Act 2
        vm.prank(TEST_USER);
        ITreasuryTest(address(treasury_proxy)).redeem(TEST_DAI, usxBurnAmount);

        /// @dev Post-action 2 assertions
        uint256 postUserBalance2 = IERC20(TEST_DAI).balanceOf(TEST_USER);
        uint256 redeemedAmount2 = postUserBalance2 - postUserBalance1;
        // Ensure that conversion price remains at the higher 3CRV price
        assertEq(ITreasuryTest(address(treasury_proxy)).previousLpTokenPrice(), TEST_3CRV_VIRTUAL_PRICE);
        // Ensure redemption matches expectation (using higher price)
        assertEq(redeemedAmount2, expectedRedeemAmount2);
    }

    function test_fail_treasury_redeem_unsupported_stable() public {
        // Test Variables
        address unsupportedStable = address(0);

        // Expectations
        vm.expectRevert("Unsupported stable.");

        // Act
        ITreasuryTest(address(treasury_proxy)).redeem(unsupportedStable, TEST_MINT_AMOUNT);
    }

    function testFail_treasury_redeem_amount(uint256 burnAmount) public {
        vm.assume(burnAmount > TEST_MINT_AMOUNT);

        /// @dev Allocate funds for test
        // Give this contract USX
        vm.prank(address(treasury_proxy));
        IUSXTest(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        // Give Treasury 3CRV
        uint256 curveAmount = calculateCurveTokenAmount(TEST_MINT_AMOUNT);
        deal(TEST_3CRV, address(treasury_proxy), curveAmount);

        /// @dev Expectations
        vm.expectEmit(true, true, true, true, address(treasury_proxy));
        emit Redemption(address(this), burnAmount);

        /// @dev Pre-action Assertions
        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), TEST_MINT_AMOUNT);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), TEST_MINT_AMOUNT);

        // Act
        ITreasuryTest(address(treasury_proxy)).redeem(TEST_DAI, burnAmount);
    }
}
// ********************************************************************************************************************************* //
// ********************************************************************************************************************************* //
// ********************************************************************************************************************************* //
// ********************************************************************************************************************************* //
// ********************************************************************************************************************************* //
// ********************************************************************************************************************************* //
contract TestEmergencySwap is Test, SharedSetup, RedeemHelper {
    /// @dev Test that 3CRV can be swapped to each supported stable, resetting chain state after each emergency swap
    function test_emergency_swap(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier < 1e7);

        /// @dev Allocate funds for test
        mintForTest(TEST_DAI, DAI_AMOUNT * amountMultiplier);

        uint256 usxTotalSupply = IUSXTest(address(usx_proxy)).totalSupply();
        // Excluding last index (3CRV)
        for (uint256 i; i < TEST_COINS.length - 1; i++) {
            /// @dev Expectations
            uint256 preStakedAmount = ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy));
            uint256 expectedTokenAmount = calculateRedeemAmount(i, preStakedAmount, TEST_COINS[i]);

            /// @dev Pre-action Assertions
            uint256 userBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), usxTotalSupply);
            assertEq(userBalanceUSX, usxTotalSupply);
            assertEq(ITreasuryTest(address(treasury_proxy)).backingToken(), TEST_3CRV);
            assertEq(ITreasuryTest(address(treasury_proxy)).backingSwapped(), false);
            assertEq(IERC20(TEST_3CRV).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_COINS[i]).balanceOf(address(treasury_proxy)), 0);

            /// @dev Act
            uint256 id = vm.snapshot();
            ITreasuryTest(address(treasury_proxy)).emergencySwapBacking(TEST_COINS[i]);

            /// @dev Post-action Assertions
            // Ensure that no USX was burned
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), usxTotalSupply);
            assertEq(userBalanceUSX, usxTotalSupply);
            
            // Ensure backingToken and backingSwapped were properly updated
            assertEq(ITreasuryTest(address(treasury_proxy)).backingToken(), TEST_COINS[i]);
            assertEq(ITreasuryTest(address(treasury_proxy)).backingSwapped(), true);

            // Ensure balances were properly updated
            assertEq(ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_3CRV).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_COINS[i]).balanceOf(address(treasury_proxy)), expectedTokenAmount);

            /// @dev Revert blockchain state to before emergency swap for next iteration
            vm.revertTo(id);
        }
    }

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

            /// @dev Revert blockchain state to before emergency swap for next iteration
            vm.revertTo(id);
            vm.stopPrank();
        }
    }

    function test_redeem_after_emergency_swap(uint256 amountMultiplier) public {
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
            uint256 preUserTokenBalance = IUSXTest(address(TEST_COINS[i])).balanceOf(TEST_USER);

            /// @dev Setup
            uint256 id = vm.snapshot();
            ITreasuryTest(address(treasury_proxy)).emergencySwapBacking(TEST_COINS[i]);

            /// @dev Pre-action Assertions
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), preUsxTotalSupply);
            assertEq(preUserBalanceUSX, preUsxTotalSupply);
            assertEq(preUserTokenBalance, 0);
            assertEq(ITreasuryTest(address(treasury_proxy)).backingToken(), TEST_COINS[i]);
            assertEq(ITreasuryTest(address(treasury_proxy)).backingSwapped(), true);
            assertEq(ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_3CRV).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_COINS[i]).balanceOf(address(treasury_proxy)), preExpectedTokenAmount);

            /// @dev Act
            vm.startPrank(TEST_USER);
            ITreasuryTest(address(treasury_proxy)).redeem(TEST_COINS[i], preUserBalanceUSX);

            /// @dev Post-action Assertions
            uint256 postUserBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
            uint256 postUserTokenBalance = IUSXTest(address(TEST_COINS[i])).balanceOf(TEST_USER);

            // Ensure the correct amount of USX was redeemed
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), 0);
            assertEq(ITreasuryTest(address(treasury_proxy)).totalSupply(), 0);

            // Ensure the user's balances were properly updated
            assertEq(postUserBalanceUSX, 0);
            assertEq(postUserTokenBalance, preExpectedTokenAmount);

            // Ensure there is no 3CRV in the Treasury or liquidity gauge
            assertEq(ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_3CRV).balanceOf(address(treasury_proxy)), 0);

            // Ensure treasury backing amount was properly updated
            assertEq(IERC20(TEST_COINS[i]).balanceOf(address(treasury_proxy)), 0);

            /// @dev Revert blockchain state to before emergency swap for next iteration
            vm.revertTo(id);
            vm.stopPrank();
        }
    }

    function test_emergency_swap_unsupported() public {
        /// @dev Allocate initial funds for test
        mintForTest(TEST_DAI, DAI_AMOUNT);

        /// @dev Expectations
        vm.expectRevert("Token not supported.");

        /// @dev Act
        // Attempt to perform emergency swap to an unsupported token
        ITreasuryTest(address(treasury_proxy)).emergencySwapBacking(TEST_3CRV);
    }

    function test_mint_after_emergency_swap_unsupported() public {
        /// @dev Allocate initial funds for test
        mintForTest(TEST_DAI, DAI_AMOUNT );
        
        // Excluding last index (3CRV)
        for (uint256 i; i < TEST_COINS.length - 1; i++) {
            /// @dev Setup
            uint256 id = vm.snapshot();
            ITreasuryTest(address(treasury_proxy)).emergencySwapBacking(TEST_COINS[i]);

            /// @dev Expectations
            uint256 stakedAmount = ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy));
            uint256 expectedTokenAmount = calculateRedeemAmount(i, stakedAmount, TEST_COINS[i]);
            vm.expectRevert("Invalid _stable.");

            /// @dev Pre-action Assertions
            assertEq(ITreasuryTest(address(treasury_proxy)).backingToken(), TEST_COINS[i]);
            assertEq(ITreasuryTest(address(treasury_proxy)).backingSwapped(), true);
            assertEq(ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_3CRV).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_COINS[i]).balanceOf(address(treasury_proxy)), expectedTokenAmount);

            /// @dev Act
            // Attempt to mint with unsupported token after emergency swap
            deal(TEST_3CRV, TEST_USER, CURVE_AMOUNT);
            uint256 amount = CURVE_AMOUNT;
            vm.startPrank(TEST_USER);
            SafeTransferLib.safeApprove(ERC20(TEST_3CRV), address(treasury_proxy), amount);
            ITreasuryTest(address(treasury_proxy)).mint(TEST_3CRV, amount);

            /// @dev Revert blockchain state to before emergency swap for next iteration
            vm.revertTo(id);
            vm.stopPrank();
        }
    }

    function test_redeem_after_emergency_swap_unsupported() public {
        /// @dev Allocate initial funds for test
        mintForTest(TEST_DAI, DAI_AMOUNT);

        // Excluding last index (3CRV)
        for (uint256 i; i < TEST_COINS.length - 1; i++) {
            /// @dev Setup
            uint256 id = vm.snapshot();
            ITreasuryTest(address(treasury_proxy)).emergencySwapBacking(TEST_COINS[i]);

            /// @dev Expectations
            uint256 stakedAmount = ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy));
            uint256 expectedTokenAmount = calculateRedeemAmount(i, stakedAmount, TEST_COINS[i]);
            vm.expectRevert("Invalid _stable.");

            /// @dev Pre-action Assertions
            assertEq(ITreasuryTest(address(treasury_proxy)).backingToken(), TEST_COINS[i]);
            assertEq(ITreasuryTest(address(treasury_proxy)).backingSwapped(), true);
            assertEq(ILiquidityGauge(TEST_LIQUIDITY_GAUGE).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_3CRV).balanceOf(address(treasury_proxy)), 0);
            assertEq(IERC20(TEST_COINS[i]).balanceOf(address(treasury_proxy)), expectedTokenAmount);

            /// @dev Act
            // Attempt to redeem with unsupported token after emergency swap
            vm.startPrank(TEST_USER);
            uint256 userBalanceUSX = IUSXTest(address(usx_proxy)).balanceOf(TEST_USER);
            ITreasuryTest(address(treasury_proxy)).redeem(TEST_3CRV, userBalanceUSX);

            /// @dev Revert blockchain state to before minting for next iteration
            vm.revertTo(id);
            vm.stopPrank();
        }
    }
}
// ********************************************************************************************************************************* //
// ********************************************************************************************************************************* //
// ********************************************************************************************************************************* //
// ********************************************************************************************************************************* //
// ********************************************************************************************************************************* //
// ********************************************************************************************************************************* //
contract TestAdmin is Test, SharedSetup {
    function test_addSupportedStable() public {
        // Test Variables
        int128 testCurveIndex = 0;

        // Pre-action Assertions
        (bool supported, int128 returnedTestCurveIndex) =
            ITreasuryTest(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, false);

        // Act
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_STABLE, testCurveIndex);

        // Post-action Assertions
        (supported, returnedTestCurveIndex) = ITreasuryTest(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, true);
        assertEq(returnedTestCurveIndex, testCurveIndex);
    }

    function test_fail_addSupportedStable_sender() public {
        // Test Variables
        int128 testCurveIndex = 0;

        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(TEST_ADDRESS);
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_STABLE, testCurveIndex);
    }

    function test_removeSupportedStable() public {
        // Setup
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_STABLE, 0);

        // Pre-action Assertions
        (bool supported, int128 returnedTestCurveIndex) =
            ITreasuryTest(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, true);
        assertEq(returnedTestCurveIndex, 0);

        // Act
        ITreasuryTest(address(treasury_proxy)).removeSupportedStable(TEST_STABLE);

        // Post-action Assertions
        (supported, returnedTestCurveIndex) = ITreasuryTest(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, false);
    }

    function test_fail_removeSupportedStable_sender() public {
        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(TEST_ADDRESS);
        ITreasuryTest(address(treasury_proxy)).removeSupportedStable(TEST_STABLE);
    }
}
