// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

// addresses
// Curve
address constant CURVE_3POOL = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;

// Tokens
address constant THREE_CRV = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;
address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

// Wormhole
address constant WORMHOLE_CORE_BRIDGE = 0x98f3c9e6E3fAce36bAAd05FE09d375Ef1464288B;
bytes32 constant TEST_TRUSTED_EMITTER = bytes32(abi.encode(0xc144b96b42924EBb9e5f7eF7B27957E576A6D102));
// TODO: Update this to the actual trusted relayer account
address constant TRUSTED_WORMHOLE_RELAYER = 0xC88E7fac500B7f8B3B3d4333F132bd21a02b4a1A;

// LayerZero
address constant LZ_ENDPOINT = 0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23;

// Will need to remove current deployment chain
contract DeployerUtils {
    uint16[] public LZ_CHAIN_IDS = [101, 110, 111, 145, 102, 109, 106];
}
