// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../src/USX.sol";
import "../../interfaces/IUSXTest.t.sol";
import "../../mocks/MockWormhole.t.sol";
import "../../common/constants.t.sol";
import "./common/TestHelpers.t.sol";

contract TestLayerZeroReceive is Test, CrossChainSetup {
    function test_lzReceive(uint256 transferAmount) public {
        vm.assume(transferAmount <= INITIAL_TOKENS);
        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit ReceiveFromChain(
            TEST_CHAIN_ID, abi.encodePacked(address(usx_proxy), address(usx_proxy)), address(this), transferAmount
            );

        // Pre-action Assertions
        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), INITIAL_TOKENS);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS);

        // Act
        vm.prank(LZ_ENDPOINT);
        IUSXTest(address(usx_proxy)).lzReceive(
            TEST_CHAIN_ID,
            abi.encodePacked(address(usx_proxy), address(usx_proxy)),
            1,
            abi.encode(abi.encodePacked(address(this)), transferAmount)
        );

        // Post-action Assertions
        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), INITIAL_TOKENS + transferAmount);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS + transferAmount);
    }

    function testCannot_lzReceive_invalid_sender(uint256 transferAmount) public {
        // Assumptions
        vm.assume(transferAmount <= INITIAL_TOKENS);

        // Expectation
        vm.expectRevert("LzApp: invalid endpoint caller");

        // Act
        IUSXTest(address(usx_proxy)).lzReceive(
            TEST_CHAIN_ID, abi.encode(address(this)), 1, abi.encode(abi.encodePacked(address(this)), transferAmount)
        );
    }

    function testCannot_lzReceive_invalid_source_address(uint256 transferAmount) public {
        // Assumptions
        vm.assume(transferAmount <= INITIAL_TOKENS);

        // Expectation
        vm.expectRevert("LzApp: invalid source sending contract");

        // Act
        vm.prank(LZ_ENDPOINT);
        IUSXTest(address(usx_proxy)).lzReceive(
            TEST_CHAIN_ID, abi.encode(address(0)), 1, abi.encode(abi.encodePacked(address(this)), transferAmount)
        );
    }
}

contract TestWormholeReceive is Test, CrossChainSetup {
    function test_processMessage(uint256 transferAmount) public {
        vm.assume(transferAmount <= INITIAL_TOKENS);

        // Setup
        vm.startPrank(TREASURY);
        IUSXTest(address(usx_proxy)).burn(address(this), INITIAL_TOKENS);
        IUSXTest(address(usx_proxy)).mint(TEST_USER, INITIAL_TOKENS);
        vm.stopPrank();

        // Mocks
        deal(address(usx_proxy), WORMHOLE_CORE_BRIDGE, transferAmount); // Mechanism to pass `transferAmount` data to Mock
        bytes memory MockWormholeCode = address(new MockWormhole()).code;
        vm.etch(WORMHOLE_CORE_BRIDGE, MockWormholeCode);

        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit ReceiveFromChain(TEST_WORMHOLE_CHAIN_ID, abi.encodePacked(TEST_USER), TEST_USER, transferAmount);

        // Pre-action Assertions
        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), INITIAL_TOKENS);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(TEST_USER), INITIAL_TOKENS);

        // Act: mocking Wormhole, so no need to send a fake VAA
        vm.prank(TRUSTED_WORMHOLE_RELAYER);
        IUSXTest(address(usx_proxy)).processMessage(bytes(""));

        // Post-action Assertions
        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), INITIAL_TOKENS + transferAmount);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(TEST_USER), INITIAL_TOKENS + transferAmount);
    }

    function testCannot_processMessage_invalid() public {
        // Setup
        vm.startPrank(TREASURY);
        IUSXTest(address(usx_proxy)).burn(address(this), INITIAL_TOKENS);
        IUSXTest(address(usx_proxy)).mint(TEST_USER, INITIAL_TOKENS);
        vm.stopPrank();

        // Mocks
        bytes memory MockWormholeCode = address(new MockWormholeInvalid()).code;
        vm.etch(WORMHOLE_CORE_BRIDGE, MockWormholeCode);

        // Expectations
        vm.expectRevert("Untrustworthy message!");

        // Act: mocking Wormhole, so no need to send a fake VAA
        vm.prank(TRUSTED_WORMHOLE_RELAYER);
        IUSXTest(address(usx_proxy)).processMessage(bytes(""));
    }

    function testCannot_processMessage_emiiter() public {
        // Setup
        vm.startPrank(TREASURY);
        IUSXTest(address(usx_proxy)).burn(address(this), INITIAL_TOKENS);
        IUSXTest(address(usx_proxy)).mint(TEST_USER, INITIAL_TOKENS);
        vm.stopPrank();

        // Mocks
        bytes memory MockWormholeCode = address(new MockWormholeUnauthorizedEmitter()).code;
        vm.etch(WORMHOLE_CORE_BRIDGE, MockWormholeCode);

        // Expectations
        vm.expectRevert("Unauthorized emitter address.");

        // Act: mocking Wormhole, so no need to send a fake VAA
        vm.prank(TRUSTED_WORMHOLE_RELAYER);
        IUSXTest(address(usx_proxy)).processMessage(bytes(""));
    }

    function testCannot_processMessage_unauthorized_relayer() public {
        // Setup
        vm.startPrank(TREASURY);
        IUSXTest(address(usx_proxy)).burn(address(this), INITIAL_TOKENS);
        IUSXTest(address(usx_proxy)).mint(TEST_USER, INITIAL_TOKENS);
        vm.stopPrank();

        // Mocks
        bytes memory MockWormholeCode = address(new MockWormhole()).code;
        vm.etch(WORMHOLE_CORE_BRIDGE, MockWormholeCode);

        // Expectations
        vm.expectRevert("Unauthorized relayer.");

        // Act: prank removed, mocking Wormhole, so no need to send a fake VAA
        IUSXTest(address(usx_proxy)).processMessage(bytes(""));
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
        IUSXTest(address(usx_proxy)).burn(address(this), INITIAL_TOKENS);
        IUSXTest(address(usx_proxy)).mint(TEST_USER, INITIAL_TOKENS);
        vm.stopPrank();

        /* ****************************************************************************
        **
        **  Successful first message
        **
        ******************************************************************************/

        // Act 1
        vm.prank(TRUSTED_WORMHOLE_RELAYER);
        IUSXTest(address(usx_proxy)).processMessage(bytes(""));

        // Post-action Assertions 1
        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), INITIAL_TOKENS + transferAmount);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(TEST_USER), INITIAL_TOKENS + transferAmount);

        /* ****************************************************************************
        **
        **  Unsuccessful second message
        **
        ******************************************************************************/

        // Expectation
        vm.expectRevert("Message already processed.");

        // Act 2: attempt to replay previous message
        vm.prank(TRUSTED_WORMHOLE_RELAYER);
        IUSXTest(address(usx_proxy)).processMessage(bytes(""));
    }
}
