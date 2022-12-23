// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "./common/TestHelpers.t.sol";
import "../../../src/token/USX.sol";
import "../../../src/proxy/ERC1967Proxy.sol";

import "../../../src/common/interfaces/IUSXAdmin.sol";

import "../../common/Constants.t.sol";
import "./common/Constants.t.sol";

contract AdminUSXTest is Test, SupplyRegulationSetup {
    function test_manageTreasuries() public {
        // Pre-action assertions
        (bool mint, bool burn) = IUSXAdmin(address(usx_proxy)).treasuries(TREASURY);
        assertEq(mint, true, "Privilege failed: should have mint privileges.");
        assertEq(burn, true, "Privilege failed: should have mint privileges.");

        // Act 1 - revoke privileges
        IUSXAdmin(address(usx_proxy)).manageTreasuries(TREASURY, false, false);

        // Post-action 1 assertions
        (mint, burn) = IUSXAdmin(address(usx_proxy)).treasuries(TREASURY);
        assertEq(mint, false, "Privilege failed: should not have mint privileges.");
        assertEq(burn, false, "Privilege failed: should not have burn privileges.");

        // Act 2 - add burn privilege
        IUSXAdmin(address(usx_proxy)).manageTreasuries(TREASURY, false, true);

        // Post-action 2 assertions
        (mint, burn) = IUSXAdmin(address(usx_proxy)).treasuries(TREASURY);
        assertEq(mint, false, "Privilege failed: should not have mint privileges.");
        assertEq(burn, true, "Privilege failed: should have burn privileges.");
    }

    function testCannot_manageTreasuries_sender() public {
        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(TEST_ADDRESS);
        IUSXAdmin(address(usx_proxy)).manageTreasuries(TREASURY, false, false);
    }

    function test_extractERC20(uint256 amount) public {
        // Test Variables
        address CVX_3RCV = 0x30D9410ED1D5DA1F6C8391af5338C93ab8d4035C;
        address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        address[4] memory COINS = [DAI, USDC, USDT, CVX_3RCV];

        // Assumptions
        for (uint256 i = 0; i < COINS.length; i++) {
            if (COINS[i] == USDC || COINS[i] == USDT) {
                vm.assume(amount > 0 && amount <= 1e6 * 1e5);
            } else {
                vm.assume(amount > 0 && amount <= 1e18 * 1e5);
            }
        }

        // Setup: deal bridge the tokens
        deal(CVX_3RCV, address(usx_proxy), amount);
        deal(DAI, address(usx_proxy), amount);
        deal(USDC, address(usx_proxy), amount);
        deal(USDT, address(usx_proxy), amount);

        for (uint256 i = 0; i < COINS.length; i++) {
            // Pre-action assertions
            assertEq(
                IERC20(COINS[i]).balanceOf(address(usx_proxy)),
                amount,
                "Equivalence violation: ERC20 token balance and amount"
            );

            // Act
            IUSXAdmin(address(usx_proxy)).extractERC20(COINS[i]);

            // Post-action assertions
            assertEq(
                IERC20(COINS[i]).balanceOf(address(usx_proxy)),
                0,
                "Equivalence violation: ERC20 token balance balance is not zero"
            );
            assertEq(
                IERC20(COINS[i]).balanceOf(address(this)),
                amount,
                "Equivalence violation: owner ERC20 token balance and amount"
            );
        }
    }

    function testCannot_extractERC20_sender(address sender, uint256 amount) public {
        // Test Variables
        address CVX_3RCV = 0x30D9410ED1D5DA1F6C8391af5338C93ab8d4035C;
        address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        address[4] memory COINS = [DAI, USDC, USDT, CVX_3RCV];

        // Assumptions
        vm.assume(sender != address(this));
        for (uint256 i = 0; i < COINS.length; i++) {
            if (COINS[i] == USDC || COINS[i] == USDT) {
                vm.assume(amount > 0 && amount <= 1e6 * 1e5);
            } else {
                vm.assume(amount > 0 && amount <= 1e18 * 1e5);
            }
        }

        // Setup: deal bridge the tokens
        deal(CVX_3RCV, address(usx_proxy), amount);
        deal(DAI, address(usx_proxy), amount);
        deal(USDC, address(usx_proxy), amount);
        deal(USDT, address(usx_proxy), amount);

        for (uint256 i = 0; i < COINS.length; i++) {
            // Exptectations
            vm.expectRevert("Ownable: caller is not the owner");

            // Act: pranking as other addresses
            vm.prank(sender);
            IUSXAdmin(address(usx_proxy)).extractERC20(COINS[i]);
        }
    }
}
