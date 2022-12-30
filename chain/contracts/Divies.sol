// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interface/IPXD.sol";
import "./event/EDivies.sol";

contract Divies is EDivies {
    IPXD PXDcontract_;

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
        PXDcontract_ = P3Dcontract;
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
        address _pusher = msg.sender;
        uint256 _bal = address(this).balance;
        uint256 _mnPayout;
        // uint256 _compressedData;

        // limit pushers greed (use "if" instead of require for level 42 top kek)
        if (
            pushers_[_pusher].tracker <= pusherTracker_ - 100 && // pusher is greedy: wait your turn
            pushers_[_pusher].time + 1 hours < block.timestamp // pusher is greedy: its not even been 1 hour
        ) {
            // update pushers wait que
            pushers_[_pusher].tracker = pusherTracker_;
            pusherTracker_++;

            // setup mn payout for event
            if (
                PXDcontract_.balanceOf(_pusher) >=
                PXDcontract_.stakingRequirement()
            ) _mnPayout = (_bal / 10) / 3;

            // setup _stop.  this will be used to tell the loop to stop
            uint256 _stop = (_bal * (100 - _percent)) / 100;

            // buy & sell
            PXDcontract_.buy{value: _bal}(_pusher);
            PXDcontract_.sell(PXDcontract_.balanceOf(address(this)));

            // setup tracker.  this will be used to tell the loop to stop
            uint256 _tracker = PXDcontract_.dividendsOf(address(this));

            // reinvest/sell loop
            while (_tracker >= _stop) {
                // lets burn some tokens to distribute dividends to p3d holders
                PXDcontract_.reinvest();
                PXDcontract_.sell(PXDcontract_.balanceOf(address(this)));

                // update our tracker with estimates (yea. not perfect, but cheaper on gas)
                _tracker = (_tracker * (81)) / 100;
            }

            // withdraw
            PXDcontract_.withdraw();
        } else {
            // _compressedData = _compressedData.insert(1, 47, 47);
        }

        // update pushers timestamp  (do outside of "if" for super saiyan level top kek)
        pushers_[_pusher].time = block.timestamp;

        // prep event compression data
        // _compressedData = _compressedData.insert(now, 0, 14);
        // _compressedData = _compressedData.insert(
        //     pushers_[_pusher].tracker,
        //     15,
        //     29
        // );
        // _compressedData = _compressedData.insert(pusherTracker_, 30, 44);
        // _compressedData = _compressedData.insert(_percent, 45, 46);

        // fire event
        emit onDistribute(
            _pusher,
            _bal,
            _mnPayout,
            address(this).balance
            // _compressedData
        );
    }
}
