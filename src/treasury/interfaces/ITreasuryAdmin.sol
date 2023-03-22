// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ITreasury } from "./ITreasury.sol";

interface ITreasuryAdmin is ITreasury {
    function addSupportedStable(address _stable, int128 _curveIndex) external;

    function removeSupportedStable(address _stable) external;

    function supportedStables(address _stable) external returns (bool, int128);

    function previousLpTokenPrice() external returns (uint256);

    function totalSupply() external returns (uint256);

    function emergencySwapBacking(address _newBackingToken) external;

    function extractERC20(address _token) external;

    function stakeCvx(uint256 _amount) external;

    function unstakeCvx(uint256 _amount) external;

    function claimRewardCvx(bool _stake) external;

    function stakeCrv(uint256 _amount) external;

    function stakeCvxCrv(uint256 _amount) external;

    function unstakeCvxCrv(uint256 _amount) external;

    function claimRewardCvxCrv() external;

    function stake3Crv(uint256 _amount) external;

    function unstake3Crv(uint256 _amount) external;

    function claimRewardCvx3Crv() external;
}
