// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract PlayerBookEvent {
    /* ------------------------------------------------------ */
    /*                         EVENTS                         */
    /* ------------------------------------------------------ */
    event onNewName(
        uint256 indexed playerID,
        address indexed playerAddress,
        bytes32 indexed playerName,
        bool isNewPlayer,
        uint256 affiliateID,
        address affiliateAddress,
        bytes32 affiliateName,
        uint256 amountPaid,
        uint256 timeStamp
    );
}
