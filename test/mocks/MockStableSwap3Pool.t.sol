// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../common/constants.t.sol";

contract MockStableSwap3Pool {
    function add_liquidity(uint256[3] calldata _amounts, uint256 _min_mint_amount) public pure returns (uint256) {
        return TEST_MINT_AMOUNT;
    }

    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 _min_amount)
        external
        pure
        returns (uint256)
    {
        return TEST_REDEMPTION_AMOUNT;
    }
}
