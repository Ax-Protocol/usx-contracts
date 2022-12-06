// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "solmate/utils/SafeTransferLib.sol";
import "../../../src/Treasury.sol";
import "../../../src/USX.sol";
import "../../../src/proxy/ERC1967Proxy.sol";
import "../../interfaces/IUSXTest.t.sol";
import "../../interfaces/ITreasuryTest.t.sol";
import "../../common/constants.t.sol";

abstract contract TreasurySetup is Test {
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

contract RedeemHelper is Test, TreasurySetup {
    function mintForTest(address _tokenAddress, uint256 _amount) internal {
        vm.startPrank(TEST_USER);
        deal(_tokenAddress, TEST_USER, _amount);
        IERC20(_tokenAddress).approve(address(treasury_proxy), _amount);
        ITreasuryTest(address(treasury_proxy)).mint(_tokenAddress, _amount);
        vm.stopPrank();
    }

    function mintForTestCurveMocked(address _tokenAddress, uint256 _amount) internal {
        // Mock Curve
        vm.mockCall(
            TEST_STABLE_SWAP_3POOL,
            abi.encodeWithSelector(IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).get_virtual_price.selector),
            abi.encode(TEST_3CRV_VIRTUAL_PRICE)
        );

        vm.startPrank(TEST_USER);
        deal(_tokenAddress, TEST_USER, _amount);
        IERC20(_tokenAddress).approve(address(treasury_proxy), _amount);
        ITreasuryTest(address(treasury_proxy)).mint(_tokenAddress, _amount);
        vm.stopPrank();
    }

    function calculateRedeemAmount(uint256 index, uint256 lpTokens, address coin)
        internal
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

    function calculateCurveTokenAmount(uint256 usxAmount) internal returns (uint256) {
        uint256 lpTokenPrice = IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).get_virtual_price();
        uint256 conversionFactor = (1e18 * 1e18 / lpTokenPrice);
        return (usxAmount * conversionFactor) / 1e18;
    }
}

contract MintHelper is Test, TreasurySetup {
    function calculateMintAmount(uint256 index, uint256 amount, address coin)
        internal
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
}
