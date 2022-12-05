// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../src/USX.sol";
import "../../../src/proxy/ERC1967Proxy.sol";
import "../../interfaces/IUSXTest.t.sol";
import "../../common/constants.t.sol";

contract TestUERC20 is Test {
    // Test Contracts
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;

    // Events
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        usx_implementation = new USX();
        usx_proxy =
        new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize(address,address)", LZ_ENDPOINT, WORMHOLE_CORE_BRIDGE));

        // Set Treasury Admin
        IUSXTest(address(usx_proxy)).manageTreasuries(TREASURY, true, true);

        // Mint Initial Tokens
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), INITIAL_TOKENS);
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

    function test_approve(uint256 approvalAmount) public {
        // Assumptions
        vm.assume(approvalAmount > 0 && approvalAmount <= INITIAL_TOKENS);

        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Approval(address(this), TEST_ADDRESS, approvalAmount);

        // Act
        IUSX(address(usx_proxy)).approve(TEST_ADDRESS, approvalAmount);

        // Assertions
        assertEq(IUSX(address(usx_proxy)).allowance(address(this), TEST_ADDRESS), approvalAmount);
    }

    function test_transfer(uint256 transferAmount) public {
        // Assumptions
        vm.assume(transferAmount > 0 && transferAmount <= INITIAL_TOKENS);

        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(this), TEST_ADDRESS, transferAmount);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS);
        assertEq(IUSX(address(usx_proxy)).balanceOf(TEST_ADDRESS), 0);

        // Act
        IUSX(address(usx_proxy)).transfer(TEST_ADDRESS, transferAmount);

        // Post-action Assertions
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS - transferAmount);
        assertEq(IUSX(address(usx_proxy)).balanceOf(TEST_ADDRESS), transferAmount);
    }

    function testFail_transfer_amount() public {
        // Expectation: FAIL. Reason: Arithmetic over/underflow

        // Act
        uint256 testFailingTransferAmount = IUSX(address(usx_proxy)).balanceOf(address(this)) + 1;
        IUSX(address(usx_proxy)).transfer(TEST_ADDRESS, testFailingTransferAmount);
    }

    function test_transferFrom(uint256 approvalAmount) public {
        vm.assume(approvalAmount > 0 && approvalAmount <= INITIAL_TOKENS);

        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(this), TEST_ADDRESS, approvalAmount);

        // Setup
        IUSX(address(usx_proxy)).approve(TEST_ADDRESS, approvalAmount);
        uint256 preActionAllowance = IUSX(address(usx_proxy)).allowance(address(this), TEST_ADDRESS);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS);
        assertEq(IUSX(address(usx_proxy)).balanceOf(TEST_ADDRESS), 0);
        assertEq(preActionAllowance, approvalAmount);

        // Act
        vm.prank(TEST_ADDRESS);
        IUSX(address(usx_proxy)).transferFrom(address(this), TEST_ADDRESS, approvalAmount);

        // Post-action Assertions
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS - approvalAmount);
        assertEq(IUSX(address(usx_proxy)).balanceOf(TEST_ADDRESS), approvalAmount);
        assertEq(IUSX(address(usx_proxy)).allowance(address(this), TEST_ADDRESS), preActionAllowance - approvalAmount);
    }

    function testFail_transferFrom_amount(uint256 approvalAmount) public {
        vm.assume(approvalAmount > 0 && approvalAmount <= INITIAL_TOKENS);

        // Setup
        IUSX(address(usx_proxy)).approve(TEST_ADDRESS, approvalAmount);

        // Act
        vm.prank(TEST_ADDRESS);
        IUSX(address(usx_proxy)).transferFrom(address(this), TEST_ADDRESS, approvalAmount + 1);
    }

    function test_permit(uint256 approvalAmount) public {
        vm.assume(approvalAmount > 0 && approvalAmount <= INITIAL_TOKENS);

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
                        approvalAmount,
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
        emit Approval(testOwner, testSpender, approvalAmount);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).allowance(testOwner, testSpender), 0);

        // Act
        vm.prank(testOwner);
        IUSXTest(address(usx_proxy)).permit(
            testOwner, testSpender, approvalAmount, block.timestamp + weekSeconds, v, r, s
        );

        // Post-action Assertions
        assertEq(IUSX(address(usx_proxy)).allowance(testOwner, testSpender), approvalAmount);
    }

    function testCannot_permit_wrong_message(uint256 approvalAmount) public {
        vm.assume(approvalAmount > 0 && approvalAmount <= INITIAL_TOKENS);

        // Test Variables
        address testSpender = 0x2F1E029b0d642b9846Ed45551deCd7e7f07ae98d;
        address testOwner = vm.addr(1);
        uint256 weekSeconds = 604800;
        bytes32 messageHash = keccak256("Wrong message.");

        // Setup
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, messageHash);

        // Expectation
        vm.expectRevert("INVALID_SIGNER");

        // Act
        vm.prank(testOwner);
        IUSXTest(address(usx_proxy)).permit(
            testOwner, testSpender, approvalAmount, block.timestamp + weekSeconds, v, r, s
        );
    }
}
