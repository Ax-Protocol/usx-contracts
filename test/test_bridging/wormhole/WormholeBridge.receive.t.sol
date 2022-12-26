// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../mocks/MockWormhole.t.sol";
import "../common/TestSetup.t.sol";

import "../../../src/common/interfaces/IUSXAdmin.sol";
import "../../../src/bridging/interfaces/IWormholeBridge.sol";

import "../../common/Constants.t.sol";

contract WormholeReceiveTest is BridgingSetup {
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

    function testCannot_processMessage_emitter() public {
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
