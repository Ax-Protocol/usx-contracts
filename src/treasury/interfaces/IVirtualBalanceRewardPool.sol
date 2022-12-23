// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface IVirtualBalanceRewardPool {
    function earned(address _account) external returns (uint256);
}
