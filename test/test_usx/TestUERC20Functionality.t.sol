// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/USX.sol";
import "../../src/proxy/ERC1967Proxy.sol";
import "../interfaces/IUSXTest.t.sol";

contract TestUERC20Functionality is Test {
    using stdStorage for StdStorage;

    // Test Contracts
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;

    // Test Constants
    address constant LZ_ENDPOINT = 0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23;
    uint256 constant INITIAL_TOKENS = 100e18;
    uint256 constant TEST_APPROVAL_AMOUNT = 10e18;
    address constant TEST_ADDRESS = 0x7e51587F7edA1b583Fde9b93ED92B289f985fe25;
    uint256 constant TEST_TRANSFER_AMOUNT = 20e18;

    // Events
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        usx_implementation = new USX();
        usx_proxy =
            new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize(address)", LZ_ENDPOINT));
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
        uint256 testFailingTransferAmount = IUSX(address(usx_proxy)).balanceOf(address(this)) + 1;
        IUSX(address(usx_proxy)).transfer(TEST_ADDRESS, testFailingTransferAmount);
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

    function test_permit() public {
        // Test Variables
        address testSpender = 0x2F1E029b0d642b9846Ed45551deCd7e7f07ae98d;
        address testOwner = vm.addr(1);
        uint256 testNonce = IUSXTest(address(usx_proxy)).nonces(testOwner);
        uint256 weekSeconds = 604800;
        uint256 deadline = block.timestamp + weekSeconds;
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                IUSXTest(address(usx_proxy)).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        testOwner,
                        testSpender,
                        TEST_APPROVAL_AMOUNT,
                        testNonce++,
                        deadline
                    )
                )
            )
        );

        // Setup
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, messageHash);

        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Approval(testOwner, testSpender, TEST_APPROVAL_AMOUNT);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).allowance(testOwner, testSpender), 0);

        // Act
        vm.prank(testOwner);
        IUSXTest(address(usx_proxy)).permit(
            testOwner, testSpender, TEST_APPROVAL_AMOUNT, block.timestamp + weekSeconds, v, r, s
        );

        // Post-action Assertions
        assertEq(IUSX(address(usx_proxy)).allowance(testOwner, testSpender), TEST_APPROVAL_AMOUNT);
    }

    function testFail_permit_wrong_message() public {
        // Test Variables
        address testSpender = 0x2F1E029b0d642b9846Ed45551deCd7e7f07ae98d;
        address testOwner = vm.addr(1);
        uint256 weekSeconds = 604800;
        bytes32 messageHash = keccak256("Wrong message.");

        // Setup
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, messageHash);

        // Act
        vm.prank(testOwner);
        IUSXTest(address(usx_proxy)).permit(
            testOwner, testSpender, TEST_APPROVAL_AMOUNT, block.timestamp + weekSeconds, v, r, s
        );
    }
}
