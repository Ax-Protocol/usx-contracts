// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IBaseRewardPool {
    /**
     * @dev withdrawAndUnwrap() only works for a BaseRewardPool address where stakingToken
     * corresponds to a Curve pool (i.e., cvx3CRV can unrwap to 3CRV). This function
     * will not work for the BaseRewardPool address that corresponds to cvxCRV, because
     * it cannot be unwrapped to CRV.
     */
    function withdrawAndUnwrap(uint256 _amount, bool _claim) external returns (bool);

    function withdraw(uint256 _amount, bool _claim) external returns (bool);

    function stake(uint256 _amount) external returns (bool);

    function getReward() external returns (bool);

    function balanceOf(address _account) external returns (uint256);

    function earned(address _account) external returns (uint256);
}
