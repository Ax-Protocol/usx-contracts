// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/USX.sol";
import "../../src/proxy/ERC1967Proxy.sol";

contract TestMintAndBurn is Test {
    using stdStorage for StdStorage;

    // Test Contracts
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;

    // Test Constants
    address constant LZ_ENDPOINT = 0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23;
    address constant TEST_ADDRESS = 0x7e51587F7edA1b583Fde9b93ED92B289f985fe25;
    uint256 constant TEST_MINT_AMOUNT = 100e18;
    uint256 constant TEST_BURN_AMOUNT = 10e18;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        usx_implementation = new USX();
        usx_proxy =
            new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize(address)", LZ_ENDPOINT));
    }

    function test_mint() public {
        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(0), address(this), TEST_MINT_AMOUNT);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), 0);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), 0);

        // Act
        IUSX(address(usx_proxy)).mint(TEST_MINT_AMOUNT);

        // Post-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), TEST_MINT_AMOUNT);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), TEST_MINT_AMOUNT);
    }

    function test_fail_mint_amount() public {
        // Expectations
        vm.expectRevert("Mint amount must be greater than zero.");

        // Act
        IUSX(address(usx_proxy)).mint(0);
    }

    function test_burn() public {
        // Setup
        IUSX(address(usx_proxy)).mint(TEST_MINT_AMOUNT);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), TEST_MINT_AMOUNT);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), TEST_MINT_AMOUNT);

        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(this), address(0), TEST_BURN_AMOUNT);

        // Act
        IUSX(address(usx_proxy)).burn(TEST_BURN_AMOUNT);

        // Post-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), TEST_MINT_AMOUNT - TEST_BURN_AMOUNT);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), TEST_MINT_AMOUNT - TEST_BURN_AMOUNT);
    }

    function test_fail_burn_amount() public {
        // Setup
        IUSX(address(usx_proxy)).mint(TEST_MINT_AMOUNT);

        // Expectations
        vm.expectRevert("Burn amount exceeds balance.");

        // Act
        IUSX(address(usx_proxy)).burn(TEST_MINT_AMOUNT + 1);
    }
}
