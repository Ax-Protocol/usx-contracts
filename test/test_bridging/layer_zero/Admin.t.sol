// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import "../../../src/token/USX.sol";
import "../../../src/proxy/ERC1967Proxy.sol";
import "../../../src/bridging/layer_zero/LayerZeroBridge.sol";

import "../../../src/bridging/interfaces/ILayerZeroBridge.sol";

import "../../common/Constants.t.sol";

contract AdminTest is Test {
    // Test Contracts
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;
    LayerZeroBridge public layer_zero_bridge;

    function setUp() public {
        usx_implementation = new USX();
        usx_proxy = new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize()"));
        layer_zero_bridge = new LayerZeroBridge(LZ_ENDPOINT, address(usx_proxy));
    }

    function test_setUseCustomAdapterParams() public {
        assertEq(ILayerZeroBridge(address(layer_zero_bridge)).useCustomAdapterParams(), false);

        ILayerZeroBridge(address(layer_zero_bridge)).setUseCustomAdapterParams(true);

        assertEq(ILayerZeroBridge(address(layer_zero_bridge)).useCustomAdapterParams(), true);
    }

    function testCannot_setUseCustomAdapterParams_sender(address sender) public {
        vm.assume(sender != address(this));

        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(sender);
        ILayerZeroBridge(address(layer_zero_bridge)).setUseCustomAdapterParams(true);
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
        deal(CVX_3RCV, address(layer_zero_bridge), amount);
        deal(DAI, address(layer_zero_bridge), amount);
        deal(USDC, address(layer_zero_bridge), amount);
        deal(USDT, address(layer_zero_bridge), amount);

        for (uint256 i = 0; i < COINS.length; i++) {
            // Pre-action assertions
            assertEq(
                IERC20(COINS[i]).balanceOf(address(layer_zero_bridge)),
                amount,
                "Equivalence violation: treausury ERC20 token balance and amount."
            );

            // Act
            ILayerZeroBridge(address(layer_zero_bridge)).extractERC20(COINS[i]);

            // Post-action assertions
            assertEq(
                IERC20(COINS[i]).balanceOf(address(layer_zero_bridge)),
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
        deal(CVX_3RCV, address(layer_zero_bridge), amount);
        deal(DAI, address(layer_zero_bridge), amount);
        deal(USDC, address(layer_zero_bridge), amount);
        deal(USDT, address(layer_zero_bridge), amount);

        for (uint256 i = 0; i < COINS.length; i++) {
            // Exptectations
            vm.expectRevert("Ownable: caller is not the owner");

            // Act: pranking as other addresses
            vm.prank(sender);
            ILayerZeroBridge(address(layer_zero_bridge)).extractERC20(COINS[i]);
        }
    }

    function test_extractNative(uint256 amount) public {
        // Setup
        vm.assume(amount > 0 && amount < 1e5);
        vm.deal(address(layer_zero_bridge), amount);

        assertEq(address(layer_zero_bridge).balance, amount, "Equivalence violation: remote balance and amount");

        uint256 preLocalBalance = address(this).balance;

        ILayerZeroBridge(address(layer_zero_bridge)).extractNative();

        assertEq(address(this).balance, preLocalBalance + amount, "Equivalence violation: local balance and amount");
    }

    function testCannot_extractNative_sender(uint256 amount, address sender) public {
        // Setup
        vm.assume(amount > 0 && amount < 1e5);
        vm.assume(sender != address(this));
        vm.deal(address(layer_zero_bridge), amount);

        // Exptectations
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(sender);
        ILayerZeroBridge(address(layer_zero_bridge)).extractNative();
    }

    receive() external payable {}
}
