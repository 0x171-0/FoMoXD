// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interface/IPXD.sol";
import "./event/EDivies.sol";

/*
 * - Divies -
 * -> What do this contract do?
 *  - 分潤給 PXD
 */
contract Divies is EDivies {
    IPXD PXD_;

    uint256 public pusherTracker_ = 100;
    mapping(address => Pusher) public pushers_;
    struct Pusher {
        uint256 tracker;
        uint256 time;
    }

    /* ------------------------------------------------------ */
    /*                        MODIFIER                        */
    /* ------------------------------------------------------ */
    modifier onlyHuman() {
        /// @dev Can't prevent attack in constructor(無法防止合約在 constructor 中攻擊)
        address sender = msg.sender;
        uint256 size;
        assembly {
            size := extcodesize(sender)
        }
        require(size == 0, "Only Human pls...");
        _;
    }

    /* ------------------------------------------------------ */
    /*                       constructor                      */
    /* ------------------------------------------------------ */
    constructor(IPXD P3Dcontract) {
        PXD_ = P3Dcontract;
    }

    /* ------------------------------------------------------ */
    /*                    receive & fallback                    
    /* ------------------------------------------------------ */
    receive() external payable {}

    fallback() external payable {}

    /* ------------------------------------------------------ */
    /*                   external functions                   */
    /* ------------------------------------------------------ */

    function deposit() external payable {}

    /* ------------------------------------------------------ */
    /*                    public funcions              
    /* ------------------------------------------------------ */
    function balances() public view returns (uint256) {
        return (address(this).balance);
    }

    function distribute(uint256 _percent) public onlyHuman {
        // make sure _percent is within boundaries
        require(
            _percent > 0 && _percent < 100,
            "please pick a percent between 1 and 99"
        );

        // data setup
        address _pusher = msg.sender; // 觸發分潤的人
        uint256 _balance = address(this).balance; // 目前待分潤的餘額
        uint256 _mnPayout;

        // limit pushers greed (use "if" instead of require for level 42 top kek)
        /// @dev 同一個使用者，在一個小時內、100 個觸發者內只能觸發一次
        if (
            pushers_[_pusher].tracker <= pusherTracker_ - 100 && // pusher is greedy: wait your turn
            pushers_[_pusher].time + 1 hours < block.timestamp // pusher is greedy: its not even been 1 hour
        ) {
            // update pushers wait que
            pushers_[_pusher].tracker = pusherTracker_;
            pusherTracker_++;

            // setup mn payout for event
            if (
                // 必需要有質押貸幣才可以當觸發者
                PXD_.balanceOf(_pusher) >= PXD_.stakingRequirement()
            ) _mnPayout = (_balance / 10) / 3;

            // setup _stop.  this will be used to tell the loop to stop
            // 決定要分幾個 Percents
            uint256 _stop = (_balance * (100 - _percent)) / 100;

            // buy & sell
            PXD_.buy{value: _balance}(_pusher);
            PXD_.sell(PXD_.balanceOf(address(this))); // 把全部 PXD Token 賣掉，PXD 抽取 10% 分潤

            // setup tracker.  this will be used to tell the loop to stop
            uint256 _tracker = PXD_.dividendsOf(address(this));

            // reinvest/sell loop
            while (_tracker >= _stop) {
                // lets burn some tokens to distribute dividends to p3d holders
                PXD_.reinvest(); // 將持有的分潤再全部都拿去買 PXD Token，PXD 抽取 10% 分潤
                PXD_.sell(PXD_.balanceOf(address(this))); // 把全部 PXD Token 賣掉獲取，PXD 抽取 10% 分潤

                // update our tracker with estimates (yea. not perfect, but cheaper on gas)
                _tracker = (_tracker * (81)) / 100;
            }

            // withdraw 剩餘的 device
            PXD_.withdraw();
        }

        // update pushers timestamp  (do outside of "if" for super saiyan level top kek)
        pushers_[_pusher].time = block.timestamp;

        // fire event
        emit onDistribute(_pusher, _balance, _mnPayout, address(this).balance);
    }
}
