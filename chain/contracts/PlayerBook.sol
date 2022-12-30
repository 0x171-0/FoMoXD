// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interface/ICommunity.sol";
import "./interface/IPlayerBookReceiver.sol";

import "./library/NameFilter.sol";
import "./event/EPlayerBook.sol";

// import "hardhat/console.sol";

contract PlayerBook is EPlayerBook {
    using NameFilter for string;
    ICommunity public Community_;
    uint256 public registrationFee_ = 1 gwei;
    uint256 public pID_; // total number of players
    uint256 public gID_; // total number of games

    // price to register a name
    struct Player {
        address addr;
        bytes32 name;
        uint256 names;
        uint256 laff;
    }

    mapping(address => uint256) public gameIDs_; // lokup a games ID
    mapping(address => bytes32) public gameNames_; // lookup a games name
    mapping(uint256 => Player) public player_; // (pID => data) player data
    mapping(address => uint256) public playerIDxAddr_; // (addr => pID) returns player id by address
    mapping(bytes32 => uint256) public pIDxName_; // (name => pID) returns player id by name
    mapping(uint256 => mapping(bytes32 => bool)) public plyrNames_; // (pID => name => bool) list of names a player owns.  (used so you can change your display name amoungst any name you own)
    mapping(uint256 => mapping(uint256 => bytes32)) public plyrNameList_; // (pID => nameNum => name) list of names a player owns
    mapping(uint256 => IPlayerBookReceiver) public games_; // mapping of our game interfaces for sending your account info to games

    /* ------------------------------------------------------ */
    /*                        MODIFIER                        */
    /* ------------------------------------------------------ */
    modifier isRegisteredGame() {
        require(gameIDs_[msg.sender] != 0);
        _;
    }

    modifier onlyDevs() {
        require(
            Community_.isDev(msg.sender) == true,
            "msg sender is not a dev"
        );
        _;
    }

    /* ------------------------------------------------------ */
    /*                        FUNCTIONS
    /* ------------------------------------------------------ */
    /* ------------------------------------------------------ */
    /*                       constructor                      */
    /* ------------------------------------------------------ */
    constructor(ICommunity _community) {
        Community_ = _community;

        player_[1].addr = msg.sender;
        player_[1].name = "admin";
        player_[1].names = 1;
        playerIDxAddr_[msg.sender] = 1;
        pIDxName_["admin"] = 1;
        plyrNames_[1]["admin"] = true;
        plyrNameList_[1][1] = "admin";

        pID_ = 1;
    }

    /* ------------------------------------------------------ */
    /*                   external functions                   */
    /* ------------------------------------------------------ */

    function getPlayerID(address _addr) external returns (uint256) {
        determinePID(_addr);
        return (playerIDxAddr_[_addr]);
    }

    function getPlayerName(uint256 _pID) external view returns (bytes32) {
        return (player_[_pID].name);
    }

    function getPlayerAddr(uint256 _pID) external view returns (address) {
        return (player_[_pID].addr);
    }

    function addGame(
        address _gameAddress,
        string calldata _gameNameStr
    ) external onlyDevs {
        require(
            gameIDs_[_gameAddress] == 0,
            "derp, that games already been registered"
        );

        // TODO: 有時間再加入多簽的設計
        // if (multiSigDev("addGame") == true) {
        // deleteProposal("addGame");
        gID_++;
        bytes32 _name = _gameNameStr.nameFilter();
        gameIDs_[_gameAddress] = gID_;
        gameNames_[_gameAddress] = _name;
        games_[gID_] = IPlayerBookReceiver(_gameAddress);

        games_[gID_].receivePlayerInfo(1, player_[1].addr, player_[1].name, 0);

        // }
    }

    function registerNameXIDFromDapp(
        address _addr,
        bytes32 _name,
        uint256 _affCode,
        bool _all
    ) external payable isRegisteredGame returns (bool, uint256) {
        // make sure name fees paid
        require(
            msg.value >= registrationFee_,
            "umm.....  you have to pay the name fee"
        );

        // set up our tx event data and determine if player is new or not
        bool _isNewPlayer = determinePID(_addr);

        // fetch player id
        uint256 _pID = playerIDxAddr_[_addr];

        // manage affiliate residuals
        // if no affiliate code was given, no new affiliate code was given, or the
        // player tried to use their own pID as an affiliate code, lolz
        uint256 _affID = _affCode;
        if (_affID != 0 && _affID != player_[_pID].laff && _affID != _pID) {
            // update last affiliate
            player_[_pID].laff = _affID;
        } else if (_affID == _pID) {
            _affID = 0;
        }

        // register name
        registerNameCore(_pID, _addr, _affID, _name, _isNewPlayer, _all);

        return (_isNewPlayer, _affID);
    }

    /* ------------------------------------------------------ */
    /*                    private functions                   */
    /* ------------------------------------------------------ */

    function registerNameCore(
        uint256 _pID,
        address _addr,
        uint256 _affID,
        bytes32 _name,
        bool _isNewPlayer,
        bool _all
    ) private {
        // if names already has been used, require that current msg sender owns the name
        if (pIDxName_[_name] != 0)
            require(
                plyrNames_[_pID][_name] == true,
                "sorry that names already taken"
            );

        // add name to player profile, registry, and name book
        player_[_pID].name = _name;
        pIDxName_[_name] = _pID;
        if (plyrNames_[_pID][_name] == false) {
            plyrNames_[_pID][_name] = true;
            player_[_pID].names++;
            plyrNameList_[_pID][player_[_pID].names] = _name;
        }

        // registration fee goes directly to community rewards
        Community_.deposit{value: address(this).balance}();

        // push player info to games
        if (_all == true) {
            for (uint256 i = 1; i <= gID_; i++) {
                games_[i].receivePlayerInfo(_pID, _addr, _name, _affID);
            }
        }

        // fire event
        emit onNewName(
            _pID,
            _addr,
            _name,
            _isNewPlayer,
            _affID,
            player_[_affID].addr,
            player_[_affID].name,
            msg.value,
            block.timestamp
        );
    }

    function determinePID(address _addr) private returns (bool) {
        if (playerIDxAddr_[_addr] == 0) {
            pID_++;
            playerIDxAddr_[_addr] = pID_;
            player_[pID_].addr = _addr;

            // set the new player bool to true
            return (true);
        } else {
            return (false);
        }
    }
}
