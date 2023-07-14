// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

// Addresses (Ethereum)
address constant LZ_ENDPOINT = 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675;
address constant WORMHOLE_CORE_BRIDGE = 0x98f3c9e6E3fAce36bAAd05FE09d375Ef1464288B;
address constant TRUSTED_WORMHOLE_RELAYER = 0xC88E7fac500B7f8B3B3d4333F132bd21a02b4a1A;
address constant TEST_ADDRESS = 0x7e51587F7edA1b583Fde9b93ED92B289f985fe25;
address constant TEST_USER = 0xe45dEeA6301901727ef13CA11F7cae79bE6d5056;
address constant FEE_SETTER = 0x2394B04B38657aF2F4Fce0E2598f49cc24322501;
address constant TREASURY = 0xD6884bfD7f67FF747FBC6334b5718c255235Bc1E;
address constant _3CRV = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;
address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

// Integers
uint64 constant WH_TEST_SEQUENCE = 1;
uint64 constant LZ_TEST_NONCE = 1;
uint16 constant TEST_LZ_CHAIN_ID = 109;
uint16 constant TEST_WORMHOLE_CHAIN_ID = 5;
uint256 constant TEST_MINT_AMOUNT = 100e18;
uint256 constant TEST_BURN_AMOUNT = 1e18;
uint256 constant _3CRV_VIRTUAL_PRICE = 1022610147775387138;
uint256 constant TEST_DEPOSIT_AMOUNT = TEST_BURN_AMOUNT;
uint256 constant INITIAL_TOKENS = 100e18;
uint256 constant TEST_TRANSFER_AMOUNT = 20e18;
uint256 constant TEST_GAS_FEE = 0.01 ether;
uint256 constant DAI_AMOUNT = 1e18;
uint256 constant USDC_AMOUNT = 1e6;
uint256 constant USDT_AMOUNT = 1e6;
uint256 constant _3CRV_AMOUNT = 1e18;

// bytes
bytes32 constant TEST_TRUSTED_EMITTER = bytes32(abi.encode(0xc144b96b42924EBb9e5f7eF7B27957E576A6D102));

contract TestUtils {
    uint16[] LZ_TEST_CHAIN_IDS = [102, 109, 106, 112, 125, 110, 111, 145];
    uint16[] WH_TEST_CHAIN_IDS = [4, 5, 6, 10, 14, 23];
    bool[] LZ_TEST_PRIVILEGES = [true, true, true, true, true, true, true, true];
    bool[] WH_TEST_PRIVILEGES = [true, true, true, true, true, true];
}
