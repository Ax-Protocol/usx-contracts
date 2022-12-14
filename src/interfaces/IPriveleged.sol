// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

interface IPriveleged {
    function manageTreasuries(address _treasury, bool _mint, bool _burn) external;

    function treasuryKillSwitch() external;
}
