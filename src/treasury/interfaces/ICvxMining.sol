// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface ICvxMining {
    function ConvertCrvToCvx(uint256 _amount) external returns (uint256);
}
