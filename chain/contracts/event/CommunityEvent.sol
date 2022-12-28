// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract CommunityEvent {
    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed txId);
    event Approve(address indexed owner, uint256 indexed txId);
    event Revoke(address indexed oener, uint256 indexed txId);
    event Execute(uint256 indexed txId);
}
