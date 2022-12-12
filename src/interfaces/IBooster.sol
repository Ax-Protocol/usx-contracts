// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IBooster {
    function deposit(uint256 _pid, uint256 _amount, bool _stake) external returns (bool);
}
