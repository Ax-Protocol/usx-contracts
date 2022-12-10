// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IBaseRewardPool{
    function withdrawAndUnwrap(uint256 _amount, bool _claim) external returns (bool);

    function balanceOf(address _account) external returns (uint256);
}