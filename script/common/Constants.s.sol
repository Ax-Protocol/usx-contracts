// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

// Will need to remove current deployment chain
contract DeployerUtils {
    uint16[] public LZ_CHAIN_IDS = [110, 102, 111, 106, 109, 112, 125, 145, 101];
    address constant WORMHOLE_CORE_BRIDGE = 0x98f3c9e6E3fAce36bAAd05FE09d375Ef1464288B;
    address constant LZ_ENDPOINT = 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675;
    address constant USX_PROXY = 0x89718f712da063Bac92CaC3468F109db852B05ff;
    address constant TREASURY_PROXY = 0x71c814A26ef81a9A3B196D73DdD1942E2DF815ed;
    address constant WH_BRIDGE_PROXY = 0x4800c8d6Ba7176F084004c0294320B634e3476f8;
    address constant LZ_BRIDGE_PROXY = 0x8d8F6f500983AC946D711E7a85661cb701C0CE5F;
}
