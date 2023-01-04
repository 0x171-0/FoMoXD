// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ITimelock {
    function GRACE_PERIOD() external view virtual returns (uint256);

    function delay() external view virtual returns (uint256);

    function queuedTransactions(
        bytes32 tId
    ) external view virtual returns (bool);

    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external virtual returns (bytes32);

    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external virtual;

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external payable virtual returns (bytes memory);
}
