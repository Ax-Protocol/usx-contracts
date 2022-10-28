// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/Treasury.sol";
import "../../src/USX.sol";
import "../../src/proxy/ERC1967Proxy.sol";
import "../../src/interfaces/IStableSwap3Pool.sol";
import "../interfaces/IUSXTest.t.sol";
import "../interfaces/ITreasuryTest.t.sol";
import "../common/constants.t.sol";
import "../mocks/MockStableSwap3Pool.t.sol";

contract TestTreasury is Test {
    using stdStorage for StdStorage;

    // Test Contracts
    Treasury public treasury_implementation;
    USX public usx_implementation;
    ERC1967Proxy public treasury_proxy;
    ERC1967Proxy public usx_proxy;
    MockStableSwap3Pool public mockStableSwap3Pool;

    // Test Constants
    address constant TEST_CURVE_TOKEN = 0x1337BedC9D22ecbe766dF105c9623922A27963EC;
    address constant TEST_STABLE_SWAP_3POOL = 0x7f90122BF0700F9E7e1F688fe926940E8839F353;
    address constant TEST_WXDAI = 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d;
    address constant TEST_USDC = 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83;
    address constant TEST_USDT = 0x4ECaBa5870353805a9F068101A40E0f32ed605C6;

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
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_WXDAI, 0);
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_USDC, 1);
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_USDT, 2);

        // Instantiate mockStableSwap3Pool
        mockStableSwap3Pool = new MockStableSwap3Pool();
    }

    function test_treasury_mint() public {
        // Expectations
        vm.expectEmit(true, true, true, true, address(treasury_proxy));
        emit Mint(address(this), TEST_MINT_AMOUNT);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), 0);

        // Mock ERC20 transferFrom
        vm.mockCall(TEST_USDC, abi.encodeWithSelector(IERC20(TEST_USDC).transferFrom.selector), abi.encode(true));

        // Mock ERC20 approve
        vm.mockCall(TEST_USDC, abi.encodeWithSelector(IERC20(TEST_USDC).approve.selector), abi.encode(true));

        // Mock Curve
        bytes memory mockStableSwap3PoolCode = address(mockStableSwap3Pool).code;
        vm.etch(address(TEST_STABLE_SWAP_3POOL), mockStableSwap3PoolCode);
        vm.mockCall(
            TEST_STABLE_SWAP_3POOL,
            abi.encodeWithSelector(IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).add_liquidity.selector),
            abi.encode(TEST_MINT_AMOUNT)
        );

        // Act
        ITreasuryTest(address(treasury_proxy)).mint(TEST_USDC, TEST_MINT_AMOUNT);

        // Post-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), TEST_MINT_AMOUNT);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), TEST_MINT_AMOUNT);
    }

    function test_fail_treasury_mint_unsupported_stable() public {
        // Test Variables
        address unsupportedStable = address(0);

        // Expectations
        vm.expectRevert("Unsupported stable.");

        // Act
        ITreasuryTest(address(treasury_proxy)).mint(unsupportedStable, TEST_MINT_AMOUNT);
    }

    function test_treasury_redeem() public {
        // Setup
        vm.prank(address(treasury_proxy));
        IUSX(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        // Expectations
        vm.expectEmit(true, true, true, true, address(treasury_proxy));
        emit Redemption(address(this), TEST_REDEMPTION_AMOUNT);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), TEST_MINT_AMOUNT);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), TEST_MINT_AMOUNT);

        // Mock Curve
        bytes memory mockStableSwap3PoolCode = address(mockStableSwap3Pool).code;
        vm.etch(address(TEST_STABLE_SWAP_3POOL), mockStableSwap3PoolCode);
        vm.mockCall(
            TEST_STABLE_SWAP_3POOL,
            abi.encodeWithSelector(IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).remove_liquidity_one_coin.selector),
            abi.encode(TEST_REDEMPTION_AMOUNT)
        );

        // Mock ERC20 transfer
        vm.mockCall(TEST_WXDAI, abi.encodeWithSelector(IERC20(TEST_WXDAI).transfer.selector), abi.encode(true));

        // Act
        ITreasuryTest(address(treasury_proxy)).redeem(TEST_WXDAI, TEST_REDEMPTION_AMOUNT);

        // Post-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), TEST_MINT_AMOUNT - TEST_REDEMPTION_AMOUNT);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), TEST_MINT_AMOUNT - TEST_REDEMPTION_AMOUNT);
    }

    function test_fail_treasury_redeem_unsupported_stable() public {
        // Test Variables
        address unsupportedStable = address(0);

        // Expectations
        vm.expectRevert("Unsupported stable.");

        // Act
        ITreasuryTest(address(treasury_proxy)).redeem(unsupportedStable, TEST_MINT_AMOUNT);
    }

    function testFail_treasury_redeem_amount() public {
        // Setup
        vm.prank(address(treasury_proxy));
        IUSX(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        // Expectations
        vm.expectEmit(true, true, true, true, address(treasury_proxy));
        emit Redemption(address(this), TEST_REDEMPTION_AMOUNT);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), TEST_MINT_AMOUNT);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), TEST_MINT_AMOUNT);

        // Mock Curve
        bytes memory mockStableSwap3PoolCode = address(mockStableSwap3Pool).code;
        vm.etch(address(TEST_STABLE_SWAP_3POOL), mockStableSwap3PoolCode);
        vm.mockCall(
            TEST_STABLE_SWAP_3POOL,
            abi.encodeWithSelector(IStableSwap3Pool(TEST_STABLE_SWAP_3POOL).remove_liquidity_one_coin.selector),
            abi.encode(TEST_REDEMPTION_AMOUNT)
        );

        // Mock ERC20 transfer
        vm.mockCall(TEST_WXDAI, abi.encodeWithSelector(IERC20(TEST_WXDAI).transfer.selector), abi.encode(true));

        // Act
        ITreasuryTest(address(treasury_proxy)).redeem(TEST_WXDAI, TEST_MINT_AMOUNT + 1);
    }
}

contract TestTreasureAdmin is Test {
    // Test Contracts
    Treasury public treasury_implementation;
    ERC1967Proxy public treasury_proxy;

    // Test Constant
    address constant TEST_STABLE = 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d;
    address constant TEST_STABLE_SWAP_3POOL = 0x7f90122BF0700F9E7e1F688fe926940E8839F353;
    address constant MOCK_USX_TOKEN = 0x552F46595F1c36CEE6c6425565dd37a67621B88c;
    address constant TEST_CURVE_TOKEN = 0x1337BedC9D22ecbe766dF105c9623922A27963EC;

    function setUp() public {
        // Deploy Treasury implementation, and link to proxy
        treasury_implementation = new Treasury();
        treasury_proxy =
        new ERC1967Proxy(address(treasury_implementation), abi.encodeWithSignature("initialize(address,address,address)", TEST_STABLE_SWAP_3POOL, MOCK_USX_TOKEN, TEST_CURVE_TOKEN));
    }

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
}
