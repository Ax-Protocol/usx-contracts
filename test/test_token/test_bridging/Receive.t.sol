// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../src/token/USX.sol";
import "../../mocks/MockWormhole.t.sol";
import "./common/TestHelpers.t.sol";

import "../../../src/common/interfaces/IUSXAdmin.sol";
import "../../../src/bridging/interfaces/ILayerZeroBridge.sol";
import "../../../src/bridging/interfaces/IWormholeBridge.sol";

import "../../common/Constants.t.sol";

contract LayerZeroReceiveTest is Test, BridgingSetup {
    function test_lzReceive(uint256 transferAmount) public {
        vm.assume(transferAmount <= INITIAL_TOKENS);

        // Expectations
        vm.expectEmit(true, true, true, true, address(layer_zero_bridge));
        emit ReceiveFromChain(
            TEST_LZ_CHAIN_ID,
            abi.encodePacked(address(layer_zero_bridge), address(layer_zero_bridge)),
            address(this),
            transferAmount
            );

        // Pre-action Assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            INITIAL_TOKENS,
            "Equivalence violation: total supply and initially minted tokens."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            INITIAL_TOKENS,
            "Equivalence violation: recipient balance and initially minted tokens."
        );

        // Act: send message, pranking as Layer Zero's contract
        vm.prank(LZ_ENDPOINT);
        ILayerZeroBridge(address(layer_zero_bridge)).lzReceive(
            TEST_LZ_CHAIN_ID,
            abi.encodePacked(address(layer_zero_bridge), address(layer_zero_bridge)),
            1,
            abi.encode(abi.encodePacked(address(this)), transferAmount)
        );

        // Assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            INITIAL_TOKENS + transferAmount,
            "Equivalence violation: total supply must increase by amount transferred."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            INITIAL_TOKENS + transferAmount,
            "Equivalence violation: recipient balance must increase by amount transferred."
        );
    }

    function testCannot_lzReceive_invalid_sender(uint256 transferAmount, address sender) public {
        // Assumptions
        vm.assume(transferAmount <= INITIAL_TOKENS);
        vm.assume(sender != LZ_ENDPOINT);

        // Expectation
        vm.expectRevert("LzApp: invalid endpoint caller");

        // Act: wrong prank
        vm.prank(sender);
        ILayerZeroBridge(address(layer_zero_bridge)).lzReceive(
            TEST_LZ_CHAIN_ID,
            abi.encodePacked(address(layer_zero_bridge), address(layer_zero_bridge)),
            1,
            abi.encode(abi.encodePacked(address(this)), transferAmount)
        );
    }

    function testCannot_lzReceive_invalid_source_address(uint256 transferAmount, address sourceAddress) public {
        // Assumptions
        vm.assume(transferAmount <= INITIAL_TOKENS);
        vm.assume(sourceAddress != address(layer_zero_bridge));

        // Expectation
        vm.expectRevert("LzApp: invalid source sending contract");

        // Act: source address not layer zero bridge
        vm.prank(LZ_ENDPOINT);
        ILayerZeroBridge(address(layer_zero_bridge)).lzReceive(
            TEST_LZ_CHAIN_ID,
            abi.encodePacked(sourceAddress, sourceAddress),
            1,
            abi.encode(abi.encodePacked(address(this)), transferAmount)
        );
    }
}

contract WormholeReceiveTest is Test, BridgingSetup {
    // NOTE: may have to remove fuzz -- how to get usx address over to mock? It's no longer msg.sender :(
    function test_processMessage(uint256 transferAmount) public {
        vm.assume(transferAmount <= INITIAL_TOKENS);

        // Setup
        vm.startPrank(TREASURY);
        IUSXAdmin(address(usx_proxy)).burn(address(this), INITIAL_TOKENS);
        IUSXAdmin(address(usx_proxy)).mint(TEST_USER, INITIAL_TOKENS);
        vm.stopPrank();

        // Mocks
        deal(address(usx_proxy), WORMHOLE_CORE_BRIDGE, transferAmount); // Mechanism to pass `transferAmount` data to Mock
        bytes memory MockWormholeCode = address(new MockWormhole()).code;
        vm.etch(WORMHOLE_CORE_BRIDGE, MockWormholeCode);

        // Expectations
        vm.expectEmit(true, true, true, true, address(wormhole_bridge));
        emit ReceiveFromChain(TEST_WORMHOLE_CHAIN_ID, abi.encodePacked(TEST_USER), TEST_USER, transferAmount);

        // Pre-action Assertions
        assertEq(IUSXAdmin(address(usx_proxy)).totalSupply(), INITIAL_TOKENS);
        assertEq(IUSXAdmin(address(usx_proxy)).balanceOf(TEST_USER), INITIAL_TOKENS);

        // Act: mocking Wormhole, so no need to send a fake VAA
        vm.prank(TRUSTED_WORMHOLE_RELAYER);
        IWormholeBridge(address(wormhole_bridge)).processMessage(bytes(""));

        // Post-action Assertions
        assertEq(IUSXAdmin(address(usx_proxy)).totalSupply(), INITIAL_TOKENS + transferAmount);
        assertEq(IUSXAdmin(address(usx_proxy)).balanceOf(TEST_USER), INITIAL_TOKENS + transferAmount);
    }

    function testCannot_processMessage_invalid() public {
        // Setup
        vm.startPrank(TREASURY);
        IUSXAdmin(address(usx_proxy)).burn(address(this), INITIAL_TOKENS);
        IUSXAdmin(address(usx_proxy)).mint(TEST_USER, INITIAL_TOKENS);
        vm.stopPrank();

        // Mocks: non-valid message
        bytes memory MockWormholeCode = address(new MockWormholeInvalid()).code;
        vm.etch(WORMHOLE_CORE_BRIDGE, MockWormholeCode);

        // Expectations
        vm.expectRevert("Untrustworthy message!");

        // Act: mocking Wormhole, so no need to send a fake VAA
        vm.prank(TRUSTED_WORMHOLE_RELAYER);
        IWormholeBridge(address(wormhole_bridge)).processMessage(bytes(""));
    }

    function testCannot_processMessage_emiiter() public {
        // Setup
        vm.startPrank(TREASURY);
        IUSXAdmin(address(usx_proxy)).burn(address(this), INITIAL_TOKENS);
        IUSXAdmin(address(usx_proxy)).mint(TEST_USER, INITIAL_TOKENS);
        vm.stopPrank();

        // Mocks: untrusted emitter address
        bytes memory MockWormholeCode = address(new MockWormholeUnauthorizedEmitter()).code;
        vm.etch(WORMHOLE_CORE_BRIDGE, MockWormholeCode);

        // Expectations
        vm.expectRevert("Unauthorized emitter address.");

        // Act: mocking Wormhole, so no need to send a fake VAA
        vm.prank(TRUSTED_WORMHOLE_RELAYER);
        IWormholeBridge(address(wormhole_bridge)).processMessage(bytes(""));
    }

    function testCannot_processMessage_unauthorized_relayer(address untrustedRelayer) public {
        // Assumptions
        vm.assume(untrustedRelayer != TRUSTED_WORMHOLE_RELAYER);

        // Setup
        vm.startPrank(TREASURY);
        IUSXAdmin(address(usx_proxy)).burn(address(this), INITIAL_TOKENS);
        IUSXAdmin(address(usx_proxy)).mint(TEST_USER, INITIAL_TOKENS);
        vm.stopPrank();

        // Mocks
        bytes memory MockWormholeCode = address(new MockWormhole()).code;
        vm.etch(WORMHOLE_CORE_BRIDGE, MockWormholeCode);

        // Expectations
        vm.expectRevert("Unauthorized relayer.");

        // Act: prank untrusted relayer
        vm.prank(untrustedRelayer);
        IWormholeBridge(address(wormhole_bridge)).processMessage(bytes(""));
    }

    function testCannot_processMessage_replay(uint256 transferAmount) public {
        // Assumption
        vm.assume(transferAmount <= INITIAL_TOKENS);

        // Mocks
        deal(address(usx_proxy), WORMHOLE_CORE_BRIDGE, transferAmount); // Mechanism to pass `transferAmount` data to Mock
        bytes memory MockWormholeCode = address(new MockWormhole()).code;
        vm.etch(WORMHOLE_CORE_BRIDGE, MockWormholeCode);

        // Setup
        vm.startPrank(TREASURY);
        IUSXAdmin(address(usx_proxy)).burn(address(this), INITIAL_TOKENS);
        IUSXAdmin(address(usx_proxy)).mint(TEST_USER, INITIAL_TOKENS);
        vm.stopPrank();

        /* ****************************************************************************
        **
        **  Successful first message
        **
        ******************************************************************************/

        // Act 1
        vm.prank(TRUSTED_WORMHOLE_RELAYER);
        IWormholeBridge(address(wormhole_bridge)).processMessage(bytes(""));

        // Post-action Assertions 1
        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            INITIAL_TOKENS + transferAmount,
            "Equivalence violation: total supply must increase by amount transferred."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(TEST_USER),
            INITIAL_TOKENS + transferAmount,
            "Equivalence violation: recipient balance must increase by amount transferred."
        );

        /* ****************************************************************************
        **
        **  Unsuccessful second message
        **
        ******************************************************************************/

        // Expectation
        vm.expectRevert("Message already processed.");

        // Act 2: attempt to replay previous message
        vm.prank(TRUSTED_WORMHOLE_RELAYER);
        IWormholeBridge(address(wormhole_bridge)).processMessage(bytes(""));
    }
}
