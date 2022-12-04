// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../src/interfaces/IWormhole.sol";
import "../common/constants.t.sol";

import "forge-std/console.sol";

contract MockWormholeCoreBridge {

    

    function parseAndVerifyVM(bytes memory) external pure returns (IWormhole.VM memory vm, bool valid, string memory reason) {
        
        IWormhole.Signature[] memory signatures;

        vm = IWormhole.VM({
            version: 1,
            timestamp: 1670023605,
            nonce: 0,
            emitterChainId: TEST_WORMHOLE_CHAIN_ID,
            emitterAddress: TRUSTED_EMITTER_ADDRESS,
            sequence: 0,
            consistencyLevel: 200,
            payload: abi.encode(abi.encodePacked(TEST_USER), 1, abi.encode(TEST_USER), TEST_TRANSFER_AMOUNT),
            guardianSetIndex: 19,
            signatures: signatures,
            hash: 0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8
        });

        valid = true;
        reason = "";
    }
}