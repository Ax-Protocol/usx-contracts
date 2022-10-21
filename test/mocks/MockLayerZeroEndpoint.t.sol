// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

contract MockLayerZeroEndpoint {
    function send() public pure returns (bool) {
        return true;
    }
}
