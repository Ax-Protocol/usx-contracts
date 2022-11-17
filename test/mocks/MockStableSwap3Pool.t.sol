// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../common/constants.t.sol";

contract MockStableSwap3Pool {
    function add_liquidity() public pure returns (uint256) {
        return TEST_MINT_AMOUNT;
    }

    function remove_liquidity_one_coin() external pure returns (uint256) {
        return TEST_REDEMPTION_AMOUNT;
    }

    function get_virtual_price() external pure returns (uint256) {
        return TEST_3CRV_VIRTUAL_PRICE;
    }
}
