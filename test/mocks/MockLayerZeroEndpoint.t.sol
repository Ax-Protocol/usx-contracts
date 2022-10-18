// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

contract MockLayerZeroEndpoint {

    function send() public pure returns (bool) {
        return true;
    }
}