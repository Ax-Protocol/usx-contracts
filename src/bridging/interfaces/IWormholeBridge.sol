// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./ILayerZeroReceiver.sol";

interface IWormholeBridge {
    function processMessage(bytes memory _vaa) external;

    function usx() external returns (address);
}
