// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/USX.sol";
import "../src/proxy/ERC1967Proxy.sol";

contract TestUERC20Functionality is Test {
    using stdStorage for StdStorage;

    // Test Contracts
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;

    // Test Constants
    uint256 constant INITIAL_TOKENS = 100e18;
    uint256 constant TEST_APPROVAL_AMOUNT = 10e18;
    address constant TEST_ADDRESS = 0x7e51587F7edA1b583Fde9b93ED92B289f985fe25;
    uint256 constant TEST_TRANSFER_AMOUNT = 20e18;

    // Events
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        usx_implementation = new USX();
        usx_proxy = new ERC1967Proxy(address(usx_implementation),  abi.encodeWithSignature("initialize()"));

        IUSX(address(usx_proxy)).mint(INITIAL_TOKENS);
    }

    function test_metadata() public {
        // Assertions
        assertEq(IUSX(address(usx_proxy)).name(), "USX");
        assertEq(IUSX(address(usx_proxy)).symbol(), "USX");
        assertEq(IUSX(address(usx_proxy)).decimals(), 18);
    }

    function test_initial_mint() public {
        // Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), INITIAL_TOKENS);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS);
    }

    function test_approve() public {
        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Approval(address(this), TEST_ADDRESS, TEST_APPROVAL_AMOUNT);

        // Act
        IUSX(address(usx_proxy)).approve(TEST_ADDRESS, TEST_APPROVAL_AMOUNT);

        // Assertions
        assertEq(IUSX(address(usx_proxy)).allowance(address(this), TEST_ADDRESS), TEST_APPROVAL_AMOUNT);
    }

    function test_transfer() public {
        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(this), TEST_ADDRESS, TEST_TRANSFER_AMOUNT);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS);
        assertEq(IUSX(address(usx_proxy)).balanceOf(TEST_ADDRESS), 0);

        // Act
        IUSX(address(usx_proxy)).transfer(TEST_ADDRESS, TEST_TRANSFER_AMOUNT);

        // Post-action Assertions
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS - TEST_TRANSFER_AMOUNT);
        assertEq(IUSX(address(usx_proxy)).balanceOf(TEST_ADDRESS), TEST_TRANSFER_AMOUNT);
    }

    function testFail_transfer_amount() public {
        // Act
        IUSX(address(usx_proxy)).transfer(TEST_ADDRESS, INITIAL_TOKENS + 1);
    }

    function test_transferFrom() public {
        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(this), TEST_ADDRESS, TEST_APPROVAL_AMOUNT);

        // Setup
        IUSX(address(usx_proxy)).approve(TEST_ADDRESS, TEST_APPROVAL_AMOUNT);
        uint256 preActionAllowance = IUSX(address(usx_proxy)).allowance(address(this), TEST_ADDRESS);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS);
        assertEq(IUSX(address(usx_proxy)).balanceOf(TEST_ADDRESS), 0);
        assertEq(preActionAllowance, TEST_APPROVAL_AMOUNT);

        // Act
        vm.prank(TEST_ADDRESS);
        IUSX(address(usx_proxy)).transferFrom(address(this), TEST_ADDRESS, TEST_APPROVAL_AMOUNT);

        // Post-action Assertions
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS - TEST_APPROVAL_AMOUNT);
        assertEq(IUSX(address(usx_proxy)).balanceOf(TEST_ADDRESS), TEST_APPROVAL_AMOUNT);
        assertEq(
            IUSX(address(usx_proxy)).allowance(address(this), TEST_ADDRESS), preActionAllowance - TEST_APPROVAL_AMOUNT
        );
    }

    function testFail_transferFrom_amount() public {
        // Setup
        IUSX(address(usx_proxy)).approve(TEST_ADDRESS, TEST_APPROVAL_AMOUNT);

        // Act
        vm.prank(TEST_ADDRESS);
        IUSX(address(usx_proxy)).transferFrom(address(this), TEST_ADDRESS, TEST_APPROVAL_AMOUNT + 1);
    }
}
