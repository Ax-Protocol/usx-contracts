// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../src/token/USX.sol";
import "../../../src/proxy/ERC1967Proxy.sol";
import "../../../src/bridging/wormhole/WormholeBridge.sol";

import "../../../src/bridging/interfaces/IWormholeBridge.sol";

import "../../common/Constants.t.sol";

contract AdminTest is Test {
    // Test Contracts
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;
    WormholeBridge public wormhole_bridge;

    // Test Variables
    uint16[] public destChainIds;
    uint256[] public fees;

    function setUp() public {
        usx_implementation = new USX();
        usx_proxy = new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize()"));
        wormhole_bridge = new WormholeBridge(WORMHOLE_CORE_BRIDGE, address(usx_proxy));
    }

    function test_manageTrustedContracts() public {
        assertEq(IWormholeBridge(address(wormhole_bridge)).trustedContracts(TEST_TRUSTED_EMITTER_ADDRESS), false);

        // Act
        IWormholeBridge(address(wormhole_bridge)).manageTrustedContracts(TEST_TRUSTED_EMITTER_ADDRESS, true);

        assertEq(IWormholeBridge(address(wormhole_bridge)).trustedContracts(TEST_TRUSTED_EMITTER_ADDRESS), true);
    }

    function testCannot_manageTrustedContracts_unauthorized(address sender) public {
        vm.assume(sender != address(this));

        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(sender);
        IWormholeBridge(address(wormhole_bridge)).manageTrustedContracts(TEST_TRUSTED_EMITTER_ADDRESS, true);
    }

    function test_manageTrustedRelayers() public {
        assertEq(IWormholeBridge(address(wormhole_bridge)).trustedRelayers(TRUSTED_WORMHOLE_RELAYER), false);

        // Act
        IWormholeBridge(address(wormhole_bridge)).manageTrustedRelayers(TRUSTED_WORMHOLE_RELAYER, true);

        assertEq(IWormholeBridge(address(wormhole_bridge)).trustedRelayers(TRUSTED_WORMHOLE_RELAYER), true);
    }

    function testCannot_manageTrustedRelayers_unauthorized(address sender) public {
        vm.assume(sender != address(this));

        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(sender);
        IWormholeBridge(address(wormhole_bridge)).manageTrustedRelayers(TRUSTED_WORMHOLE_RELAYER, true);
    }

    function test_getTrustedContracts() public {
        // Setup
        bytes32[3] memory testTrustedEmitters = [
            bytes32(abi.encode(0xc144b96b42924EBb9e5f7eF7B27957E576A6D102)),
            bytes32(abi.encode(0xD3Ba011d21C200a8520f72A67494269Fc259921E)),
            bytes32(abi.encode(0xB78535ca0CFA787455e65BFFC0f4446472F5E297))
        ];

        for (uint256 i = 0; i < testTrustedEmitters.length; i++) {
            IWormholeBridge(address(wormhole_bridge)).manageTrustedContracts(testTrustedEmitters[i], true);
        }

        // Act
        bytes32[] memory trustedEmitters = IWormholeBridge(address(wormhole_bridge)).getTrustedContracts();

        // Assertions
        for (uint256 i = 0; i < testTrustedEmitters.length; i++) {
            assertEq(trustedEmitters[i], testTrustedEmitters[i]);
        }
    }

    function testCannot_getTrustedContracts_unauthorized(address sender) public {
        vm.assume(sender != address(this));

        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(sender);
        IWormholeBridge(address(wormhole_bridge)).getTrustedContracts();
    }

    function test_getTrustedRelayers() public {
        // Setup
        address[3] memory testTrustedRelayers = [
            0x456BeD4bE47d36221f017FB850b1dd41c4678490,
            0xeeCE0Ce45f3562263fc70Ff796b672f5818ED436,
            0x8A65B1aB965dE3D1f1d90BE7999eB15D490fb271
        ];

        for (uint256 i = 0; i < testTrustedRelayers.length; i++) {
            IWormholeBridge(address(wormhole_bridge)).manageTrustedRelayers(testTrustedRelayers[i], true);
        }

        // Act
        address[] memory trustedRelayers = IWormholeBridge(address(wormhole_bridge)).getTrustedRelayers();

        // Assertions
        for (uint256 i = 0; i < testTrustedRelayers.length; i++) {
            assertEq(trustedRelayers[i], testTrustedRelayers[i]);
        }
    }

    function testCannot_getTrustedRelayers_unauthorized(address sender) public {
        vm.assume(sender != address(this));

        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(sender);
        IWormholeBridge(address(wormhole_bridge)).getTrustedRelayers();
    }

    function test_extractERC20(uint256 amount) public {
        // Test Variables
        address[4] memory COINS = [DAI, USDC, USDT, _3CRV];

        // Assumptions
        for (uint256 i = 0; i < COINS.length; i++) {
            if (COINS[i] == USDC || COINS[i] == USDT) {
                vm.assume(amount > 0 && amount <= 1e6 * 1e5);
            } else {
                vm.assume(amount > 0 && amount <= 1e18 * 1e5);
            }
        }

        // Setup: deal bridge the tokens
        deal(DAI, address(wormhole_bridge), amount);
        deal(USDC, address(wormhole_bridge), amount);
        deal(USDT, address(wormhole_bridge), amount);
        deal(_3CRV, address(wormhole_bridge), amount);

        for (uint256 i = 0; i < COINS.length; i++) {
            // Pre-action assertions
            assertEq(
                IERC20(COINS[i]).balanceOf(address(wormhole_bridge)),
                amount,
                "Equivalence violation: ERC20 token balance and amount"
            );

            // Act
            IWormholeBridge(address(wormhole_bridge)).extractERC20(COINS[i]);

            // Post-action assertions
            assertEq(
                IERC20(COINS[i]).balanceOf(address(wormhole_bridge)),
                0,
                "Equivalence violation: ERC20 token balance is not zero"
            );
            assertEq(
                IERC20(COINS[i]).balanceOf(address(this)),
                amount,
                "Equivalence violation: owner ERC20 balance and amount"
            );
        }
    }

    function testCannot_extractERC20_unauthorized(address sender, uint256 amount) public {
        // Test Variables
        address[4] memory COINS = [DAI, USDC, USDT, _3CRV];

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
        deal(DAI, address(wormhole_bridge), amount);
        deal(USDC, address(wormhole_bridge), amount);
        deal(USDT, address(wormhole_bridge), amount);
        deal(_3CRV, address(wormhole_bridge), amount);

        for (uint256 i = 0; i < COINS.length; i++) {
            // Exptectations
            vm.expectRevert("Ownable: caller is not the owner");

            // Act: pranking as other addresses
            vm.prank(sender);
            IWormholeBridge(address(wormhole_bridge)).extractERC20(COINS[i]);
        }
    }

    function test_extractNative(uint256 amount) public {
        // Setup
        vm.assume(amount > 0 && amount < 1e22);
        vm.deal(address(wormhole_bridge), amount);

        assertEq(address(wormhole_bridge).balance, amount, "Equivalence violation: remote balance and amount");

        uint256 preLocalBalance = address(this).balance;

        IWormholeBridge(address(wormhole_bridge)).extractNative();

        assertEq(address(this).balance, preLocalBalance + amount, "Equivalence violation: local balance and amount");
    }

    function testCannot_extractNative_unauthorized(uint256 amount, address sender) public {
        // Setup
        vm.assume(amount > 0 && amount < 1e22);
        vm.assume(sender != address(this));
        vm.deal(address(wormhole_bridge), amount);

        // Exptectations
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(sender);
        IWormholeBridge(address(wormhole_bridge)).extractNative();
    }

    function test_setSendFees_update_all(uint256 fee) public {
        // Assumptions
        vm.assume(fee >= 1e15 && fee < 5e16);

        // Setup
        uint256 testCases = 4;

        for (uint256 i = 1; i < (testCases + 1); i++) {
            destChainIds.push(uint16(i));
            fees.push(fee);
        }

        // Pre-action assertions
        for (uint256 i = 0; i < destChainIds.length; i++) {
            uint256 destFee = wormhole_bridge.sendFeeLookup(destChainIds[i]);
            assertEq(destFee, 0, "Equivalence violation: destFee should be 0, but it's not.");
        }

        // Act: update
        IWormholeBridge(address(wormhole_bridge)).setSendFees(destChainIds, fees);

        // Post-action assertions
        for (uint256 i = 0; i < destChainIds.length; i++) {
            uint256 destFee = wormhole_bridge.sendFeeLookup(destChainIds[i]);
            assertEq(destFee, fees[i], "Equivalence violation: destFee and updated fee.");
        }
    }

    function test_setSendFees_update_some(uint256 fee) public {
        // Assumptions
        vm.assume(fee >= 1e15 && fee < 5e16);

        // Setup
        uint256 testCases = 4;

        for (uint256 i = 1; i < (testCases + 1); i++) {
            destChainIds.push(uint16(i));
            fees.push(fee);
        }

        IWormholeBridge(address(wormhole_bridge)).setSendFees(destChainIds, fees);

        uint256[] memory old_fees = fees;

        for (uint256 i = 0; i < destChainIds.length; i++) {
            if (i % 2 == 0) {
                fees[i] = 0;
            } else {
                fees[i] *= 2;
            }
        }

        // Act: update, with some fees as zero
        IWormholeBridge(address(wormhole_bridge)).setSendFees(destChainIds, fees);

        // Post-action assertions
        for (uint256 i = 0; i < fees.length; i++) {
            uint256 destFee = wormhole_bridge.sendFeeLookup(destChainIds[i]);
            if (fees[i] == 0) {
                assertEq(destFee, old_fees[i], "Equivalence violation: destFee and old fee.");
            } else {
                assertEq(destFee, fees[i], "Equivalence violation: destFee and updated fee.");
            }
        }
    }

    function testCannot_setSendFees_unauthorized(uint256 fee, address sender) public {
        // Assumptions
        vm.assume(fee >= 1e15 && fee < 5e16);
        vm.assume(sender != address(this));

        // Setup
        uint256 testCases = 4;

        for (uint256 i = 1; i < (testCases + 1); i++) {
            destChainIds.push(uint16(i));
            fees.push(fee);
        }

        // Exptectations
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(sender);
        IWormholeBridge(address(wormhole_bridge)).setSendFees(destChainIds, fees);
    }

    receive() external payable {}
}
