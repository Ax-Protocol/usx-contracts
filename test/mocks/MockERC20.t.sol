// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../common/constants.t.sol";

contract MockERC20 {
    uint256 private counter;

    function balance0f(address account) public returns (uint256 balance) {
        if (account == TEST_3CRV) {
            if (counter == 0) {
                balance = 0;
            } else if (counter == 1) {
                // Does not include Curve fees, actual would be slightly lower
                balance = (TEST_DEPOSIT_AMOUNT / TEST_3CRV_VIRTUAL_PRICE) * 1e18;
            }
        } else {
            if (counter == 0) {
                balance = 0;
            } else if (counter == 1) {
                // Does not include Curve fees, actual would be slightly lower
                balance = TEST_BURN_AMOUNT;
            }
        }

        counter++;
    }

    function transferFrom(address, address, uint256) public pure returns (bool) {
        return true;
    }

    function approve(address, uint256) public pure returns (bool) {
        return true;
    }
}
