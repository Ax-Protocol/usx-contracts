// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IUSX } from "./IUSX.sol";
import { IUERC20 } from "./IUERC20.sol";

interface IUSXAdmin is IUSX, IUERC20 {
    error Paused();

    function treasuryKillSwitch() external;

    function upgradeTo(address newImplementation) external;

    function manageTreasuries(address _treasury, bool _mint, bool _burn) external;

    function treasuries(address _treasury) external returns (bool mint, bool burn);

    function manageCrossChainTransfers(address[2] calldata _bridgeAddresses, bool[2] calldata _privileges) external;

    function transferPrivileges(address _bridge) external returns (bool);

    function extractERC20(address _token) external;
}
