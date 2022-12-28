// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "../library/FXDdatasets.sol";

contract FXDevents {
    /* ------------------------------------------------------ */
    /*                         Events                         */
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

    event onWithdraw(
        uint256 indexed playerID,
        address playerAddress,
        uint256 ethOut
        // bytes32 playerName
    );

    event onBuyPuff(
        uint256 indexed playerId,
        address playerAddress,
        uint256 ethIn,
        uint256 puffssBought,
        uint256 amountWon,
        uint256 P3DShare,
        uint256 generalShare,
        uint256 airDropPotShare,
        uint256 potShare,
        uint256 indexed affId
    );

    event onEndRound(
        uint256 indexed roundId,
        uint256 indexed winnerId,
        FXDdatasets.Teams winnerTeamId,
        uint256 generalShare,
        uint256 winnerShare
    );

    event onEthAirdrop(uint256 indexed playerID, uint256 prize);

    event onNftAirdrop(
        uint256 indexed roundId,
        address indexed playerAddr,
        uint256[] tokenIds
    );

    event onAffiliatePayout(
        uint256 indexed affiliateID,
        address indexedaffiliateAddress,
        bytes32 affiliateName,
        uint256 indexed roundID,
        uint256 indexed buyerID,
        uint256 amount,
        uint256 timeStamp
    );
}
