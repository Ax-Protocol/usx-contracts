// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./ITreasury.sol";

interface ITreasuryAdmin is ITreasury {
    function addSupportedStable(address _stable, int128 _curveIndex) external;

    function removeSupportedStable(address _stable) external;

    function supportedStables(address _stable) external returns (bool, int128);

    function previousLpTokenPrice() external returns (uint256);

    function totalSupply() external returns (uint256);

    function emergencySwapBacking(address _newBackingToken) external;

    function extractERC20(address _token) external;
}
