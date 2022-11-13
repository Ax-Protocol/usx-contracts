// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../../src/interfaces/ITreasury.sol";

interface ITreasuryTest is ITreasury {
    function addSupportedStable(address _stable, int128 _curveIndex) external;

    function removeSupportedStable(address _stable) external;

    function supportedStables(address _stable) external returns (bool, int128);
}
