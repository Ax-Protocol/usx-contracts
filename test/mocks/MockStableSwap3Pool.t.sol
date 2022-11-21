// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../common/constants.t.sol";

contract MockStableSwap3Pool {
    uint256 constant AMPLIFIER = 1e6;
    uint256 public counter;

    function add_liquidity(uint256[3] calldata _amounts, uint256 _min_mint_amount) public pure {}

    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 _min_amount) public pure {}

    function get_virtual_price() public pure returns (uint256) {
        return TEST_3CRV_VIRTUAL_PRICE;
    }
}
