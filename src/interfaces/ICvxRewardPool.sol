// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface ICvxRewardPool {
    function stake(uint256 _amount) external;

    function getReward(bool _stake) external;

    function withdraw(uint256 _amount, bool claim) external;

    function balanceOf(address _account) external returns (uint256);

    function earned(address _account) external returns (uint256);
}
