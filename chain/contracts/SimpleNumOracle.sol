// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "./interface/INumOracle.sol";

// import "hardhat/console.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 */

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

contract SimpleNumOracle is INumOracle, VRFConsumerBaseV2, ConfirmedOwner {
    /* ------------------------------------------------------ */
    /*                        CONTRACT
    /* ------------------------------------------------------ */
    address public FoMoXD_;
    /* ------------------------------------------------------ */
    /*                      CONFIGURATION                     */
    /* ------------------------------------------------------ */
    // Your subscription ID.
    uint64 s_subscriptionId;
    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash =
        0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 2;
    /* ------------------------------------------------------ */
    /*                         STORAGE                        */
    /* ------------------------------------------------------ */
    uint256 requestId_; // mock chain link request id
    uint256 public airDropTracker_ = 0; // incremented each time a "qualified" tx occurs.  used to determine winning air drop
    uint256 public airERC721Tracker_ = 0;
    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */
    VRFCoordinatorV2Interface COORDINATOR;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;
    /* ------------------------------------------------------ */
    /*                         Events                         */
    /* ------------------------------------------------------ */
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    /* ------------------------------------------------------ */
    /*                        Modifier                        */
    /* ------------------------------------------------------ */
    modifier onlyFoMoXD() {
        require(msg.sender == address(FoMoXD_), "only team just can activate");
        _;
    }

    /* ------------------------------------------------------ */
    /*                        FUNCTIONS
    /* ------------------------------------------------------ */
    /* ------------------------------------------------------ */
    /*                       constructor                      */
    /* ------------------------------------------------------ */
    /**
     * HARDCODED FOR GOERLI
     * COORDINATOR: 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D
     */
    constructor(
        uint64 subscriptionId
    )
        VRFConsumerBaseV2(0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D)
        ConfirmedOwner(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(
            0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D
        );
        s_subscriptionId = subscriptionId;
    }

    /* ------------------------------------------------------ */
    /*                   external functions                   */
    /* ------------------------------------------------------ */

    function setFoMoGame(address _FoMoXD) external onlyOwner {
        FoMoXD_ = _FoMoXD;
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    function isAirdrop() external override onlyFoMoXD returns (bool) {
        uint256 requestId = requestRandomWords();
        uint256[] memory _randomWords = s_requests[requestId].randomWords;
        uint256 seed;
        for (uint256 i; i < _randomWords.length; i++) {
            seed += _randomWords[i];
        }
        // TODO: for testing
        if (seed % 2 == 0) {
            // if ((seed - ((seed / 1000) * 1000)) < airDropTracker_) {
            // reset air drop tracker
            airDropTracker_ = 0;
            return (true);
        } else {
            airDropTracker_++; // 第幾輪都沒有人中
            return (false);
        }
    }

    function isAirdropNfts() external override onlyFoMoXD returns (bool) {
        uint256 requestId = requestRandomWords();
        uint256[] memory _randomWords = s_requests[requestId].randomWords;
        uint256 seed;
        for (uint256 i; i < _randomWords.length; i++) {
            seed += _randomWords[i];
        }
        // TODO: for testing
        if (seed % 2 == 0) {
            // if ((seed - ((seed / 1000) * 1000)) < airDropTracker_) {
            // reset air drop tracker
            airDropTracker_ = 0;
            return (true);
        } else {
            airDropTracker_++; // 第幾輪都沒有人中
            return (false);
        }
    }

    /* ------------------------------------------------------ */
    /*                   public functions                   
    /* ------------------------------------------------------ */

    // Assumes the subscription is funded sufficiently.
    function requestRandomWords() public returns (uint256) {
        // Will revert if subscription is not set and funded.
        // Just for testing
        requestId_++;
        uint256 _requestId = requestId_;
        // requestId = COORDINATOR.requestRandomWords(
        //     keyHash,
        //     s_subscriptionId,
        //     requestConfirmations,
        //     callbackGasLimit,
        //     numWords
        // );
        s_requests[_requestId] = RequestStatus({
            randomWords: new uint256[](numWords),
            exists: true,
            fulfilled: false
        });

        requestIds.push(_requestId);
        lastRequestId = _requestId;

        emit RequestSent(_requestId, numWords);
        /* -------------- mock chain link call back ------------- */
        fulfillRandomWords(_requestId, chainlinkCallbackMock(_requestId));
        return _requestId;
    }

    /* ------------------------------------------------------ */
    /*                   internal functions                   */
    /* ------------------------------------------------------ */

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function chainlinkCallbackMock(
        uint256 _requestId
    ) internal returns (uint256[] memory) {
        uint256[] memory result = new uint256[](numWords);
        uint256 numWordsWaitGenerate = 0;
        while (numWordsWaitGenerate < numWords - 1) {
            result[numWordsWaitGenerate] ==
                uint256(
                    keccak256(
                        abi.encodePacked(
                            (block.timestamp) +
                                (block.difficulty) +
                                ((
                                    uint256(
                                        keccak256(
                                            abi.encodePacked(block.coinbase)
                                        )
                                    )
                                ) / (block.timestamp)) +
                                (block.gaslimit) +
                                ((
                                    uint256(
                                        keccak256(abi.encodePacked(msg.sender))
                                    )
                                ) / (block.timestamp)) +
                                (block.number)
                        )
                    )
                );
            numWordsWaitGenerate++;
        }
        return result;
    }
}
