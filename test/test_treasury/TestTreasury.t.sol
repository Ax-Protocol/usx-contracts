// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "solmate/utils/SafeTransferLib.sol";
import "../../src/Treasury.sol";
import "../../src/USX.sol";
import "../../src/proxy/ERC1967Proxy.sol";
import "../../src/interfaces/IStableSwap3Pool.sol";
import "../../src/interfaces/IERC20.sol";
import "../interfaces/IUSXTest.t.sol";
import "../interfaces/ITreasuryTest.t.sol";
import "../common/constants.t.sol";

abstract contract SharedSetup is Test {
    // Test Contracts
    Treasury public treasury_implementation;
    USX public usx_implementation;
    ERC1967Proxy public treasury_proxy;
    ERC1967Proxy public usx_proxy;

    // Test Constants

    address constant TEST_CURVE_TOKEN = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490; // Ethereum
    address constant TEST_STABLE_SWAP_3POOL = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7; // Ethereum
    address constant TEST_DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // Ethereum
    address constant TEST_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // Ethereum
    address constant TEST_USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // Ethereum
    address constant TEST_STABLE = 0xaD37Cd49a9dd24BE734212AEFA1b862ead92eEF2;
    address constant TEST_USER = 0x19Bb08638DD185b7455ffD1bB96765108B0aB556;
    address[4] TEST_COINS = [TEST_DAI, TEST_USDC, TEST_USDT, TEST_CURVE_TOKEN];

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
        new ERC1967Proxy(address(treasury_implementation), abi.encodeWithSignature("initialize(address,address,address)", TEST_STABLE_SWAP_3POOL, address(usx_proxy), TEST_CURVE_TOKEN));

        // Set treasury admin on token contract
        IUSXTest(address(usx_proxy)).manageTreasuries(address(treasury_proxy), true, true);

        // Set supported stable coins on treasury contract
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_DAI, 0);
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_USDC, 1);
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_USDT, 2);

        // Fund test user with ERC20 balances
        deal(TEST_DAI, address(TEST_USER), DAI_AMOUNT);
        deal(TEST_USDC, address(TEST_USER), USDC_AMOUNT);
        deal(TEST_USDT, address(TEST_USER), USDT_AMOUNT);
        deal(TEST_CURVE_TOKEN, address(TEST_USER), CURVE_AMOUNT);
    }
}

contract TestTreasury is Test, SharedSetup {
    function calculateMintAmount(uint256 index, uint256 amount, address coin) private returns (uint256) {
        // Take snapshot before calculation
        uint256 id = vm.snapshot();

        // Add liquidity
        uint256 lpTokens;
        if (coin != TEST_CURVE_TOKEN) {
            SafeTransferLib.safeApprove(ERC20(coin), TEST_STABLE_SWAP_3POOL, amount);
            uint256[3] memory amounts;
            amounts[index] = amount;
            uint256 preBalance = IERC20(TEST_CURVE_TOKEN).balanceOf(TEST_USER);
            IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).add_liquidity(amounts, 0);
            uint256 postBalance = IERC20(TEST_CURVE_TOKEN).balanceOf(TEST_USER);
            lpTokens = postBalance - preBalance;
        } else {
            lpTokens = amount;
        }

        // Obtain 3CRV price
        uint256 lpTokenPrice = IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).get_virtual_price();

        // Revert to blockchain state before Curve interaction
        vm.revertTo(id);

        // Return expected mint amount
        return (lpTokens * lpTokenPrice) / 1e18;
    }

    function test_treasury_mint() public {
        vm.startPrank(TEST_USER);

        uint256 totalMinted;
        for (uint256 i; i < TEST_COINS.length; i++) {
            // Expectations
            uint256 expectedMintAmount = calculateMintAmount(i, TEST_AMOUNTS[i], TEST_COINS[i]);
            vm.expectEmit(true, true, true, true, address(treasury_proxy));
            emit Mint(TEST_USER, expectedMintAmount);

            // Pre-action Assertions
            uint256 preBalance = IUSX(address(usx_proxy)).balanceOf(TEST_USER);
            assertEq(IUSX(address(usx_proxy)).totalSupply(), totalMinted);
            assertEq(preBalance, totalMinted);

            // Act
            SafeTransferLib.safeApprove(ERC20(TEST_COINS[i]), address(treasury_proxy), TEST_AMOUNTS[i]);
            ITreasuryTest(address(treasury_proxy)).mint(TEST_COINS[i], TEST_AMOUNTS[i]);

            // Post-action Assertions
            uint256 postBalance = IUSX(address(usx_proxy)).balanceOf(TEST_USER);
            uint256 amountMinted = postBalance - preBalance;
            assertEq(amountMinted, expectedMintAmount);
            assertEq(IUSX(address(usx_proxy)).totalSupply(), totalMinted + amountMinted);

            totalMinted += amountMinted;
        }
    }

    function test_fail_treasury_mint_unsupported_stable() public {
        // Test Variables
        address unsupportedStable = address(0);

        // Expectations
        vm.expectRevert("Unsupported stable.");

        // Act
        ITreasuryTest(address(treasury_proxy)).mint(unsupportedStable, TEST_MINT_AMOUNT);
    }

    // function test_treasury_redeem() public {
    //     // Setup
    //     deal(address(usx_proxy), address(TEST_USER), USX_AMOUNT * 3);
    //     deal(address(usx_proxy), address(TEST_USER), USX_AMOUNT * 3);

    //     vm.startPrank(TEST_USER);

    //     uint usxSupply;
    //     for (uint i; i < TEST_COINS.length; i++) {
    //         // Expectations
    //         vm.expectEmit(true, true, true, true, address(treasury_proxy));
    //         // emit Redemption(address(this), TEST_REDEMPTION_AMOUNT);

    //         // Pre-action Assertions
    //         uint preBalance = IUSX(address(usx_proxy)).balanceOf(TEST_USER);
    //         assertEq(IUSX(address(usx_proxy)).totalSupply(), usxSupply);
    //         assertEq(preBalance, usxSupply);

    //         // Act
    //         ITreasuryTest(address(treasury_proxy)).redeem(TEST_COINS[i], TEST_AMOUNTS[i]);

    //         // Post-action Assertions
    //         uint postBalance = IUSX(address(usx_proxy)).balanceOf(TEST_USER);
    //         uint amountMinted = postBalance - preBalance;
    //         assertEq(amountMinted, expectedMintAmount);
    //         assertEq(IUSX(address(usx_proxy)).totalSupply(), totalMinted + amountMinted);

    //         totalMinted += amountMinted;
    //     }

    //     // Expectations
    //     vm.expectEmit(true, true, true, true, address(treasury_proxy));
    //     emit Redemption(address(this), TEST_REDEMPTION_AMOUNT);

    //     // Pre-action Assertions
    //     assertEq(IUSX(address(usx_proxy)).totalSupply(), TEST_MINT_AMOUNT);
    //     assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), TEST_MINT_AMOUNT);

    //     // Act
    //     ITreasuryTest(address(treasury_proxy)).redeem(TEST_WXDAI, TEST_REDEMPTION_AMOUNT);

    //     // Post-action Assertions
    //     assertEq(IUSX(address(usx_proxy)).totalSupply(), TEST_MINT_AMOUNT - TEST_REDEMPTION_AMOUNT);
    //     assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), TEST_MINT_AMOUNT - TEST_REDEMPTION_AMOUNT);
    // }

    // function test_fail_treasury_redeem_unsupported_stable() public {
    //     // Test Variables
    //     address unsupportedStable = address(0);

    //     // Expectations
    //     vm.expectRevert("Unsupported stable.");

    //     // Act
    //     ITreasuryTest(address(treasury_proxy)).redeem(unsupportedStable, TEST_MINT_AMOUNT);
    // }

    // function testFail_treasury_redeem_amount() public {
    //     // Setup
    //     vm.prank(address(treasury_proxy));
    //     IUSX(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

    //     // Expectations
    //     vm.expectEmit(true, true, true, true, address(treasury_proxy));
    //     emit Redemption(address(this), TEST_REDEMPTION_AMOUNT);

    //     // Pre-action Assertions
    //     assertEq(IUSX(address(usx_proxy)).totalSupply(), TEST_MINT_AMOUNT);
    //     assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), TEST_MINT_AMOUNT);

    //     // Mock Curve
    //     bytes memory mockStableSwap3PoolCode = address(mockStableSwap3Pool).code;
    //     vm.etch(address(TEST_STABLE_SWAP_3POOL), mockStableSwap3PoolCode);
    //     vm.mockCall(
    //         TEST_STABLE_SWAP_3POOL,
    //         abi.encodeWithSelector(IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).remove_liquidity_one_coin.selector),
    //         abi.encode(TEST_REDEMPTION_AMOUNT)
    //     );

    //     // Mock ERC20 transfer
    //     vm.mockCall(TEST_WXDAI, abi.encodeWithSelector(IERC20(TEST_WXDAI).transfer.selector), abi.encode(true));

    //     // Act
    //     ITreasuryTest(address(treasury_proxy)).redeem(TEST_WXDAI, TEST_MINT_AMOUNT + 1);
    // }
}

// contract TestAdmin is Test, SharedSetup {
//     function test_addSupportedStable() public {
//         // Test Variables
//         int128 testCurveIndex = 0;

//         // Pre-action Assertions
//         (bool supported, int128 returnedTestCurveIndex) =
//             ITreasuryTest(address(treasury_proxy)).supportedStables(TEST_STABLE);
//         assertEq(supported, false);

//         // Act
//         ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_STABLE, testCurveIndex);

//         // Post-action Assertions
//         (supported, returnedTestCurveIndex) = ITreasuryTest(address(treasury_proxy)).supportedStables(TEST_STABLE);
//         assertEq(supported, true);
//         assertEq(returnedTestCurveIndex, testCurveIndex);
//     }

//     function test_fail_addSupportedStable_sender() public {
//         // Test Variables
//         int128 testCurveIndex = 0;

//         // Expectations
//         vm.expectRevert("Ownable: caller is not the owner");

//         // Act
//         vm.prank(TEST_ADDRESS);
//         ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_STABLE, testCurveIndex);
//     }

//     function test_removeSupportedStable() public {
//         // Setup
//         ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_STABLE, 0);

//         // Pre-action Assertions
//         (bool supported, int128 returnedTestCurveIndex) =
//             ITreasuryTest(address(treasury_proxy)).supportedStables(TEST_STABLE);
//         assertEq(supported, true);
//         assertEq(returnedTestCurveIndex, 0);

//         // Act
//         ITreasuryTest(address(treasury_proxy)).removeSupportedStable(TEST_STABLE);

//         // Post-action Assertions
//         (supported, returnedTestCurveIndex) = ITreasuryTest(address(treasury_proxy)).supportedStables(TEST_STABLE);
//         assertEq(supported, false);
//     }

//     function test_fail_removeSupportedStable_sender() public {
//         // Expectations
//         vm.expectRevert("Ownable: caller is not the owner");

//         // Act
//         vm.prank(TEST_ADDRESS);
//         ITreasuryTest(address(treasury_proxy)).removeSupportedStable(TEST_STABLE);
//     }
// }
