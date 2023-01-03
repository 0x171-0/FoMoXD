// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library FXDdatasets {
    enum Teams {
        CHOCO,
        BANA,
        BERRY,
        KIWI
    }
    struct Round {
        uint256 ico;
        uint256 winnerId; // pID of player in lead， lead领导吗？
        Teams winnerTeamId; // tID of team in lead
        /* ------------------------ Time ------------------------ */
        uint256 startTime; // time round started
        uint256 endTime; // time ends/ended
        bool ended; // has round end function been ran  这个开关值得研究下
        /* ------------------------- $$$ ------------------------ */
        uint256 puffs; // puffs
        uint256 eth; // total eth in
        uint256 pot; // eth to pot (during round) / final amount paid to winner (after round ends)
        // mask = global profit that can be withdraw
        uint256 mask;
        uint256 nfts;
    }
    struct PlayerRounds {
        uint256 eth; // eth player has added to round (used for eth limiter)
        uint256 puffs; // puffs
        // mask = profit user has withdrawed
        uint256 mask; // player profit mask, everytime withdraw will get profit from round mask and update player mask
    }

    struct Player {
        address addr; // player address
        bytes32 name; // player name
        uint256 lastRound; // last round played
        uint256 lastAffiliateId; // last affiliate id used // TODO: 每一次買 Key 的推薦人都可以不一樣？
        /* ----------- $$$ of all rounds------------------------ */
        uint256 winningVault; // winnings vault
        uint256 generalVault; // general vault
        uint256 affiliateVault; // affiliate vault
    }

    struct TeamFee {
        uint256 generalShare; // % of buy in thats paid to puff holders of current round
        uint256 pXdShare; // % of buy in thats paid to pXd holders
    }
    struct PotSplit {
        uint256 generalShare; // % of pot thats paid to puff holders of current round
        uint256 pXdShare; // % of pot thats paid to pXd holders
    }
}
