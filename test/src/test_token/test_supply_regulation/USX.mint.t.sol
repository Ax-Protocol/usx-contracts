// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../../../src/token/USX.sol";
import "../../../../src/proxy/ERC1967Proxy.sol";

import "../../../../src/common/interfaces/IUSXAdmin.sol";

import "./common/TestSetup.t.sol";
import "../../common/Constants.t.sol";

contract MintUSXTest is SupplyRegulationSetup {
    function test_mint(uint256 mintAmount) public {
        // Assumptions
        vm.assume(mintAmount < 1e11);

        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(0), address(this), mintAmount);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), 0, "Equivalence violation: total supply should be 0.");
        assertEq(
            IUSX(address(usx_proxy)).balanceOf(address(this)), 0, "Equivalence violation: user balance should be 0."
        );

        // Act
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), mintAmount);

        // Post-action Assertions
        assertEq(
            IUSX(address(usx_proxy)).totalSupply(), mintAmount, "Equivalence violation: total supply and mintAmount."
        );
        assertEq(
            IUSX(address(usx_proxy)).balanceOf(address(this)),
            mintAmount,
            "Equivalence violation: user balance and mintAmount."
        );
    }

    function testCannot_mint_unauthorized(uint256 mintAmount) public {
        // Assumptions
        vm.assume(mintAmount < 1e11);

        // Expectations
        vm.expectRevert("Unauthorized.");

        // Act: no prank
        IUSX(address(usx_proxy)).mint(address(this), mintAmount);
    }
}
