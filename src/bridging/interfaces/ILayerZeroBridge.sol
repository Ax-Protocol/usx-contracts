// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./ILayerZeroReceiver.sol";

interface ILayerZeroBridge is ILayerZeroReceiver {
    //Admin functions
    function setUseCustomAdapterParams(bool _useCustomAdapterParams) external;

    function useCustomAdapterParams() external returns (bool);
}
