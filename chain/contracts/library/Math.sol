// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library Math {
    /**
     * @dev gives square root of given x.
     */
    function sqrt(uint256 x) public pure returns (uint256 y) {
        uint256 z = (((x + 1)) / 2);
        y = x;
        while (z < y) {
            y = z;
            z = ((((x / z) + z)) / 2);
        }
    }
}
