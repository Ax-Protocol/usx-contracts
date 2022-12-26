// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "solmate/utils/SafeTransferLib.sol";
import "../../../src/treasury/Treasury.sol";
import "../../../src/token/USX.sol";
import "../../../src/proxy/ERC1967Proxy.sol";

import "../../../src/common/interfaces/IUSXAdmin.sol";
import "../../../src/treasury/interfaces/ITreasuryAdmin.sol";

import "../../common/Constants.t.sol";

abstract contract TreasurySetup is Test {
    // Test Contracts
    Treasury public treasury_implementation;
    USX public usx_implementation;
    ERC1967Proxy public treasury_proxy;
    ERC1967Proxy public usx_proxy;

    // Test Constants
    uint8 public constant PID_3POOL = 9;
    address constant STABLE_SWAP_3POOL = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address constant BOOSTER = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;
    address constant CVX_3CRV_BASE_REWARD_POOL = 0x689440f2Ff927E1f24c72F1087E1FAF471eCe1c8;
    address constant CVX_CRV_BASE_REWARD_POOL = 0x3Fe65692bfCD0e6CF84cB1E7d24108E434A7587e;
    address constant CVX_REWARD_POOL = 0xCF50b810E57Ac33B91dCF525C6ddd9881B139332;
    address constant CRV_DEPOSITOR = 0x8014595F2AB54cD7c604B00E9fb932176fDc86Ae;
    address constant CVX_MINING = 0x3c75BFe6FbfDa3A94E7E7E8c2216AFc684dE5343;
    address constant VIRTUAL_BALANCE_REWARD_POOL = 0x7091dbb7fcbA54569eF1387Ac89Eb2a5C9F6d2EA;
    address constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    address constant CVX_CRV = 0x62B9c7356A2Dc64a1969e19C23e4f579F9810Aa7;
    address constant CVX_3RCV = 0x30D9410ED1D5DA1F6C8391af5338C93ab8d4035C;
    address constant TEST_STABLE = 0xaD37Cd49a9dd24BE734212AEFA1b862ead92eEF2;
    address[4] TEST_COINS = [DAI, USDC, USDT, _3CRV];

    uint256 constant ONE_WEEK = 604800;
    uint256 constant CRV_AMOUNT = 1e18;
    uint256 constant CVX_AMOUNT = 1e18;
    uint256 constant CVX_CRV_AMOUNT = 1e18;
    uint256 constant USX_AMOUNT = 1e18;
    uint256[4] TEST_AMOUNTS = [DAI_AMOUNT, USDC_AMOUNT, USDT_AMOUNT, _3CRV_AMOUNT];

    // Events
    event Mint(address indexed account, uint256 amount);
    event Redemption(address indexed account, uint256 amount);

    function setUp() public {
        // Deploy USX implementation, and link to proxy
        usx_implementation = new USX();
        usx_proxy = new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize()"));

        // Deploy Treasury implementation, and link to proxy
        treasury_implementation = new Treasury();
        treasury_proxy =
        new ERC1967Proxy(address(treasury_implementation), abi.encodeWithSignature("initialize(address)", address(usx_proxy)));

        // Set treasury admin on USX contract
        IUSXAdmin(address(usx_proxy)).manageTreasuries(address(treasury_proxy), true, true);

        // Set supported stable coins on treasury contract
        ITreasuryAdmin(address(treasury_proxy)).addSupportedStable(DAI, 0);
        ITreasuryAdmin(address(treasury_proxy)).addSupportedStable(USDC, 1);
        ITreasuryAdmin(address(treasury_proxy)).addSupportedStable(USDT, 2);
    }

    function test_setUpState() public {
        (bool mint, bool burn) = IUSXAdmin(address(usx_proxy)).treasuries(address(treasury_proxy));

        assertEq(mint, true, "Error: treasury does not have minting priveleges");
        assertEq(burn, true, "Error: treasury does not have burning priveleges");
    }
}

contract FundingHelper is Test, TreasurySetup {
    function _mintForTest(address _tokenAddress, uint256 _amount) internal {
        vm.startPrank(TEST_USER);
        deal(_tokenAddress, TEST_USER, _amount);
        IERC20(_tokenAddress).approve(address(treasury_proxy), _amount);
        ITreasuryAdmin(address(treasury_proxy)).mint(_tokenAddress, _amount);
        vm.stopPrank();
    }
}

contract RedeemHelper is Test, FundingHelper {
    function _mintForTestCurveMocked(address _tokenAddress, uint256 _amount) internal {
        // Mock Curve
        vm.mockCall(
            STABLE_SWAP_3POOL,
            abi.encodeWithSelector(ICurve3Pool(STABLE_SWAP_3POOL).get_virtual_price.selector),
            abi.encode(_3CRV_VIRTUAL_PRICE)
        );

        vm.startPrank(TEST_USER);
        deal(_tokenAddress, TEST_USER, _amount);
        IERC20(_tokenAddress).approve(address(treasury_proxy), _amount);
        ITreasuryAdmin(address(treasury_proxy)).mint(_tokenAddress, _amount);
        vm.stopPrank();
    }

    function _calculateRedeemAmount(uint256 index, uint256 lpTokens, address coin)
        internal
        returns (uint256 redeemAmount)
    {
        // Take snapshot before calculation
        uint256 id = vm.snapshot();

        if (coin != _3CRV) {
            vm.startPrank(address(treasury_proxy));

            // Unstake 3CRV
            IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).withdrawAndUnwrap(lpTokens, true);

            // Obtain contract's withdraw token balance before adding removing liquidity
            uint256 preBalance = IERC20(coin).balanceOf(address(treasury_proxy));

            // Remove liquidity from Curve
            ICurve3Pool(STABLE_SWAP_3POOL).remove_liquidity_one_coin(lpTokens, int128(uint128(index)), 0);

            // Calculate the amount of stablecoin received from removing liquidity
            redeemAmount = IERC20(coin).balanceOf(address(treasury_proxy)) - preBalance;
            vm.stopPrank();
        } else {
            redeemAmount = lpTokens;
        }

        // Revert to blockchain state before Curve interaction
        vm.revertTo(id);
    }

    function _calculateCurveTokenAmount(uint256 usxAmount) internal returns (uint256) {
        uint256 lpTokenPrice = ICurve3Pool(STABLE_SWAP_3POOL).get_virtual_price();
        uint256 conversionFactor = (1e18 * 1e18 / lpTokenPrice);
        return (usxAmount * conversionFactor) / 1e18;
    }
}

contract MintHelper is Test, TreasurySetup {
    function _calculateMintAmount(uint256 index, uint256 amount, address coin)
        internal
        returns (uint256 mintAmount, uint256 lpTokens)
    {
        // Take snapshot before calculation
        uint256 id = vm.snapshot();

        // Add liquidity
        if (coin != _3CRV) {
            SafeTransferLib.safeApprove(ERC20(coin), STABLE_SWAP_3POOL, amount);
            uint256[3] memory amounts;
            amounts[index] = amount;
            uint256 preBalance = IERC20(_3CRV).balanceOf(TEST_USER);
            ICurve3Pool(STABLE_SWAP_3POOL).add_liquidity(amounts, 0);
            uint256 postBalance = IERC20(_3CRV).balanceOf(TEST_USER);
            lpTokens = postBalance - preBalance;
        } else {
            lpTokens = amount;
        }

        // Obtain 3CRV price
        uint256 lpTokenPrice = ICurve3Pool(STABLE_SWAP_3POOL).get_virtual_price();

        // Revert to blockchain state before Curve interaction
        vm.revertTo(id);

        // Return expected mint amount
        mintAmount = (lpTokens * lpTokenPrice) / 1e18;
    }
}
