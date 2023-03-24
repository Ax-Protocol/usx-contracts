// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import "../../../../src/token/USX.sol";
import "../../../../src/proxy/ERC1967Proxy.sol";
import "../../../../src/bridging/layer_zero/LayerZeroBridge.sol";

import "../../../../src/bridging/interfaces/ILayerZeroBridge.sol";

import "../../common/Constants.t.sol";

contract AdminTest is Test {
    // Test Contracts
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;
    LayerZeroBridge public layer_zero_bridge;
    ERC1967Proxy public layer_zero_bridge_proxy;

    function setUp() public {
        usx_implementation = new USX();
        usx_proxy = new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize()"));
        layer_zero_bridge = new LayerZeroBridge();
        layer_zero_bridge_proxy =
        new ERC1967Proxy(address(layer_zero_bridge), abi.encodeWithSignature("initialize(address,address)", LZ_ENDPOINT, address(usx_proxy)));
    }

    function test_setUseCustomAdapterParams() public {
        assertEq(ILayerZeroBridge(address(layer_zero_bridge_proxy)).useCustomAdapterParams(), false);

        ILayerZeroBridge(address(layer_zero_bridge_proxy)).setUseCustomAdapterParams(true);

        assertEq(ILayerZeroBridge(address(layer_zero_bridge_proxy)).useCustomAdapterParams(), true);
    }

    function testCannot_setUseCustomAdapterParams_unauthorized(address sender) public {
        vm.assume(sender != address(this));

        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(sender);
        ILayerZeroBridge(address(layer_zero_bridge_proxy)).setUseCustomAdapterParams(true);
    }

    function test_extractERC20(uint256 amount) public {
        // Test Variables
        address[4] memory COINS = [DAI, USDC, USDT, _3CRV];

        // Assumptions
        for (uint256 i; i < COINS.length; i++) {
            if (COINS[i] == USDC || COINS[i] == USDT) {
                vm.assume(amount > 0 && amount <= 1e6 * 1e5);
            } else {
                vm.assume(amount > 0 && amount <= 1e18 * 1e5);
            }
        }

        // Setup: deal bridge the tokens
        deal(DAI, address(layer_zero_bridge_proxy), amount);
        deal(USDC, address(layer_zero_bridge_proxy), amount);
        deal(USDT, address(layer_zero_bridge_proxy), amount);
        deal(_3CRV, address(layer_zero_bridge_proxy), amount);

        for (uint256 i; i < COINS.length; i++) {
            // Pre-action assertions
            assertEq(
                IERC20(COINS[i]).balanceOf(address(layer_zero_bridge_proxy)),
                amount,
                "Equivalence violation: treausury ERC20 token balance and amount."
            );

            // Act
            ILayerZeroBridge(address(layer_zero_bridge_proxy)).extractERC20(COINS[i]);

            // Post-action assertions
            assertEq(
                IERC20(COINS[i]).balanceOf(address(layer_zero_bridge_proxy)),
                0,
                "Equivalence violation: treausury ERC20 token balance is not zero."
            );
            assertEq(
                IERC20(COINS[i]).balanceOf(address(this)),
                amount,
                "Equivalence violation: owner ERC20 token balance and amount."
            );
        }
    }

    function testCannot_extractERC20_unauthorized(address sender, uint256 amount) public {
        // Test Variables
        address[4] memory COINS = [DAI, USDC, USDT, _3CRV];

        // Assumptions
        vm.assume(sender != address(this));
        for (uint256 i; i < COINS.length; i++) {
            if (COINS[i] == USDC || COINS[i] == USDT) {
                vm.assume(amount > 0 && amount <= 1e6 * 1e5);
            } else {
                vm.assume(amount > 0 && amount <= 1e18 * 1e5);
            }
        }

        // Setup: deal bridge the tokens
        deal(DAI, address(layer_zero_bridge_proxy), amount);
        deal(USDC, address(layer_zero_bridge_proxy), amount);
        deal(USDT, address(layer_zero_bridge_proxy), amount);
        deal(_3CRV, address(layer_zero_bridge_proxy), amount);

        for (uint256 i; i < COINS.length; i++) {
            // Exptectations
            vm.expectRevert("Ownable: caller is not the owner");

            // Act: pranking as other addresses
            vm.prank(sender);
            ILayerZeroBridge(address(layer_zero_bridge_proxy)).extractERC20(COINS[i]);
        }
    }

    function test_extractNative(uint256 amount) public {
        // Setup
        vm.assume(amount > 0 && amount < 1e22);
        vm.deal(address(layer_zero_bridge_proxy), amount);

        assertEq(address(layer_zero_bridge_proxy).balance, amount, "Equivalence violation: remote balance and amount");

        uint256 preLocalBalance = address(this).balance;

        ILayerZeroBridge(address(layer_zero_bridge_proxy)).extractNative();

        assertEq(address(this).balance, preLocalBalance + amount, "Equivalence violation: local balance and amount");
    }

    function testCannot_extractNative_unauthorized(uint256 amount, address sender) public {
        // Setup
        vm.assume(amount > 0 && amount < 1e22);
        vm.assume(sender != address(this));
        vm.deal(address(layer_zero_bridge_proxy), amount);

        // Exptectations
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(sender);
        ILayerZeroBridge(address(layer_zero_bridge_proxy)).extractNative();
    }

    receive() external payable { }
}
