// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../src/bridging/interfaces/IWormhole.sol";
import "../../src/bridging/interfaces/IWormholeBridge.sol";
import "../../src/common/interfaces/IERC20.sol";
import "../common/Constants.t.sol";

import "forge-std/console.sol";

contract WormholeHelper {
    function getVM() internal returns (IWormhole.VM memory) {
        address usx = IWormholeBridge(msg.sender).usx();
        uint256 transferAmount = IERC20(usx).balanceOf(address(this));

        IWormhole.Signature[] memory signatures;

        return IWormhole.VM({
            version: 1,
            timestamp: 1670023605,
            nonce: 0,
            emitterChainId: TEST_WORMHOLE_CHAIN_ID,
            emitterAddress: TEST_TRUSTED_EMITTER_ADDRESS,
            sequence: 0,
            consistencyLevel: 200,
            payload: abi.encode(abi.encodePacked(TEST_USER), 1, abi.encode(TEST_USER), transferAmount),
            guardianSetIndex: 19,
            signatures: signatures,
            hash: 0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8
        });
    }
}

contract MockWormhole is WormholeHelper {
    function parseAndVerifyVM(bytes memory)
        external
        returns (IWormhole.VM memory vm, bool valid, string memory reason)
    {
        console.log("\n\nWE GOT HERE WORM!!!");
        vm = getVM();
        valid = true;
        reason = "";
    }
}

contract MockWormholeInvalid is WormholeHelper {
    function parseAndVerifyVM(bytes memory)
        external
        returns (IWormhole.VM memory vm, bool valid, string memory reason)
    {
        vm = getVM();
        valid = false;
        reason = "Untrustworthy message!";
    }
}

contract MockWormholeUnauthorizedEmitter is WormholeHelper {
    function parseAndVerifyVM(bytes memory)
        external
        returns (IWormhole.VM memory vm, bool valid, string memory reason)
    {
        // Test variables
        bytes32 unauthorizedEmitter = bytes32(abi.encode(0xb9fB91D13f9Bc14a4370e3dC13c0510fe649Dde3));

        vm = getVM();
        vm.emitterAddress = unauthorizedEmitter;
        valid = true;
        reason = "";
    }
}
