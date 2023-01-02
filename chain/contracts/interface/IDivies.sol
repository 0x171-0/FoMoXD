// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IDivies {
    function balances() external view returns (uint256);

    function deposit() external payable;

    /**
     * @dev allow user to trigger distribution and get reward
     * 讓使用者可以來觸發分潤並獲得獎勵
     */
    function distribute(uint256 _percent) external;
}
