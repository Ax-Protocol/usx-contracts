// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../src/USX.sol";
import "../../../src/proxy/ERC1967Proxy.sol";
import "../../interfaces/IUSXTest.t.sol";
import "../../common/constants.t.sol";

abstract contract SharedSetup is Test {
    // Test Contracts
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        // Deploy USX implementation, and link to proxy
        usx_implementation = new USX();
        usx_proxy =
            new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize(address,address)", LZ_ENDPOINT, WORMHOLE_CORE_BRIDGE));

        // Set Treasury Admin
        IUSXTest(address(usx_proxy)).manageTreasuries(TREASURY, true, true);
    }
}

contract TestMintUSX is Test, SharedSetup {
    function test_mint(uint256 mintAmount) public {
        // Assumptions
        vm.assume(mintAmount < 1e11);

        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(0), address(this), mintAmount);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), 0);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), 0);

        // Act
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), mintAmount);

        // Post-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), mintAmount);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), mintAmount);
    }

    function test_fail_mint_unauthorized(uint256 mintAmount) public {
        // Assumptions
        vm.assume(mintAmount < 1e11);

        // Expectations
        vm.expectRevert("Unauthorized.");

        // Act
        IUSX(address(usx_proxy)).mint(address(this), mintAmount);
    }
}

contract TestBurnUSX is Test, SharedSetup {
    function test_burn(uint256 testBurnAmount) public {
        // Assumptions
        vm.assume(testBurnAmount <= TEST_MINT_AMOUNT);

        // Setup
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), TEST_MINT_AMOUNT);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), TEST_MINT_AMOUNT);

        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(this), address(0), testBurnAmount);

        // Act
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).burn(address(this), testBurnAmount);

        // Post-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), TEST_MINT_AMOUNT - testBurnAmount);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), TEST_MINT_AMOUNT - testBurnAmount);
    }

    function testFail_burn_amount(uint256 testInvalidBurnAmount) public {
        // Assumptions
        vm.assume(testInvalidBurnAmount > TEST_MINT_AMOUNT);

        // Setup
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        // Act
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).burn(address(this), testInvalidBurnAmount);
    }

    function test_fail_burn_unauthorized(uint256 testBurnAmount) public {
        // Assumptions
        vm.assume(testBurnAmount <= TEST_MINT_AMOUNT);

        // Setup
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        // Expectations
        vm.expectRevert("Unauthorized.");

        // Act
        IUSX(address(usx_proxy)).burn(address(this), testBurnAmount);
    }
}

contract TestAdminUSX is Test, SharedSetup {
    function testManageTreasuries() public {
        // Pre-action assertions
        (bool mint, bool burn) = IUSXTest(address(usx_proxy)).treasuries(TREASURY);
        assertEq(mint, true);
        assertEq(burn, true);

        // Act 1 - revoke privileges
        IUSXTest(address(usx_proxy)).manageTreasuries(TREASURY, false, false);

        // Post-action 1 assertions
        (mint, burn) = IUSXTest(address(usx_proxy)).treasuries(TREASURY);
        assertEq(mint, false);
        assertEq(burn, false);

        // Act 2 - add burn privilege
        IUSXTest(address(usx_proxy)).manageTreasuries(TREASURY, false, true);

        // Post-action 2 assertions
        (mint, burn) = IUSXTest(address(usx_proxy)).treasuries(TREASURY);
        assertEq(mint, false);
        assertEq(burn, true);
    }

    function testManageTreasuries_sender() public {
        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(TEST_ADDRESS);
        IUSXTest(address(usx_proxy)).manageTreasuries(TREASURY, false, false);
    }
}

contract TestTreasuriesUSX is Test, SharedSetup {
    /// @dev Integration tests.

    function test_manageTreasuries_mint_integration() public {
        // Test Variables
        uint256 BALANCE_AFTER_FIRST_MINT = TEST_MINT_AMOUNT;
        uint256 BALANCE_AFTER_SECOND_MINT = BALANCE_AFTER_FIRST_MINT + TEST_MINT_AMOUNT;

        // 1. Ensure can mint
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(0), address(this), TEST_MINT_AMOUNT);

        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        assertEq(IUSX(address(usx_proxy)).totalSupply(), BALANCE_AFTER_FIRST_MINT);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), BALANCE_AFTER_FIRST_MINT);

        // 2. Revoke mint privileges
        IUSXTest(address(usx_proxy)).manageTreasuries(TREASURY, false, true);

        // 3. Ensure cannot mint
        vm.expectRevert("Unauthorized.");
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        // 4. Reinstate mint privileges
        IUSXTest(address(usx_proxy)).manageTreasuries(TREASURY, true, true);

        // 5. Ensure can mint again
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(0), address(this), TEST_MINT_AMOUNT);

        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        assertEq(IUSX(address(usx_proxy)).totalSupply(), BALANCE_AFTER_SECOND_MINT);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), BALANCE_AFTER_SECOND_MINT);
    }

    function test_manageTreasuries_burn_integration(uint256) public {
        // Test Variables
        uint256 BALANCE_AFTER_FIRST_BURN = TEST_MINT_AMOUNT - TEST_BURN_AMOUNT;
        uint256 BALANCE_AFTER_SECOND_BURN = BALANCE_AFTER_FIRST_BURN - TEST_BURN_AMOUNT;

        // 1. Ensure can burn
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(this), address(0), TEST_BURN_AMOUNT);

        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).burn(address(this), TEST_BURN_AMOUNT);

        assertEq(IUSX(address(usx_proxy)).totalSupply(), BALANCE_AFTER_FIRST_BURN);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), BALANCE_AFTER_FIRST_BURN);

        // 2. Revoke burn privileges
        IUSXTest(address(usx_proxy)).manageTreasuries(TREASURY, true, false);

        // 3. Ensure cannot burn
        vm.expectRevert("Unauthorized.");
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).burn(address(this), TEST_BURN_AMOUNT);

        // 4. Reinstate burn privileges
        IUSXTest(address(usx_proxy)).manageTreasuries(TREASURY, true, true);

        // 5. Ensure can burn again
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(this), address(0), TEST_BURN_AMOUNT);

        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).burn(address(this), TEST_BURN_AMOUNT);

        assertEq(IUSX(address(usx_proxy)).totalSupply(), BALANCE_AFTER_SECOND_BURN);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), BALANCE_AFTER_SECOND_BURN);
    }
}
