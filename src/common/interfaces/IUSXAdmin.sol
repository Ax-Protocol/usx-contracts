// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./IUSX.sol";
import "./IERC20Extended.sol";

interface IUSXAdmin is IUSX, IERC20Extended {
    error Paused();

    function treasuryKillSwitch() external;

    function upgradeTo(address newImplementation) external;

    function manageTreasuries(address _treasury, bool _mint, bool _burn) external;

    function treasuries(address _treasury) external returns (bool mint, bool burn);

    function manageCrossChainTransfers(address[2] calldata _bridgeAddresses, bool[2] calldata _privileges) external;

    function transferPrivileges(uint8 _bridgeID) external returns (bool);

    function extractERC20(address _token) external;
}
