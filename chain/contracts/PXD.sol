// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./event/EPXD.sol";

import "./library/Math.sol";
import "./interface/IPXD.sol";

contract PXD is ERC20, EPXD, Math, IPXD {
    /* ------------------------------------------------------ */
    /*                      CONFIGURABLES                     */
    /* ------------------------------------------------------ */
    uint8 internal constant dividendFee_ = 10; // 買賣幣都會抽取 10% 手續費

    /// @dev 最一開始的價格
    uint256 internal constant tokenPriceInitial_ = 0.0000001 ether;

    ///
    uint256 internal constant tokenPriceIncremental_ = 0.00000001 ether;

    uint256 internal constant magnitude = 2 ** 64;

    // proof of stake (defaults at 100 tokens)
    uint256 public stakingRequirement = 100e18;

    // ambassador program
    mapping(address => bool) internal ambassadors_;
    uint256 internal constant ambassadorMaxPurchase_ = 1 ether;
    uint256 internal constant ambassadorQuota_ = 20 ether;
    /* ------------------------------------------------------ */
    /*                        DATASETS                        */
    /* ------------------------------------------------------ */
    // amount of shares for each address (scaled number)
    mapping(address => uint256) internal tokenBalanceLedger_;
    mapping(address => uint256) internal referralBalance_;
    mapping(address => int256) internal payoutsTo_;
    mapping(address => uint256) internal ambassadorAccumulatedQuota_;
    uint256 internal tokenSupply_ = 0;
    uint256 internal profitPerShare_;

    // administrator list (see above on what they can do)
    mapping(bytes32 => bool) public administrators;

    // when this is set to true, only ambassadors can purchase tokens (this prevents a whale premine, it ensures a fairly distributed upper pyramid)
    bool public onlyAmbassadors = true;

    /* ------------------------------------------------------ */
    /*                        MODIFIER                        */
    /* ------------------------------------------------------ */
    // only people with tokens
    modifier onlyBagholders() {
        require(myTokens() > 0);
        _;
    }

    // only people with profits
    modifier onlyStronghands() {
        require(myDividends(true) > 0);
        _;
    }

    // administrators can:
    // -> change the name of the contract
    // -> change the name of the token
    // -> change the PoS difficulty (How many tokens it costs to hold a masternode, in case it gets crazy high later)
    // they CANNOT:
    // -> take funds
    // -> disable withdrawals
    // -> kill the contract
    // -> change the price of tokens
    modifier onlyAdministrator() {
        address _customerAddress = msg.sender;
        require(administrators[keccak256(abi.encodePacked(_customerAddress))]);
        _;
    }

    // ensures that the first tokens in the contract will be equally distributed
    // meaning, no divine dump will be ever possible
    // result: healthy longevity.
    modifier antiEarlyWhale(uint256 _amountOfEthereum) {
        address _customerAddress = msg.sender;

        // are we still in the vulnerable phase?
        // if so, enact anti early whale protocol
        if (
            onlyAmbassadors &&
            ((totalEthereumBalance() - _amountOfEthereum) <= ambassadorQuota_)
        ) {
            require(
                // is the customer in the ambassador list?
                ambassadors_[_customerAddress] == true &&
                    // does the customer purchase exceed the max ambassador quota?
                    (ambassadorAccumulatedQuota_[_customerAddress] +
                        _amountOfEthereum) <=
                    ambassadorMaxPurchase_
            );

            // updated the accumulated quota
            ambassadorAccumulatedQuota_[_customerAddress] += _amountOfEthereum;

            // execute
            _;
        } else {
            // in case the ether count drops low, the ambassador phase won't reinitiate
            onlyAmbassadors = false;
            _;
        }
    }

    /* ------------------------------------------------------ */
    /*                       constructor                      */
    /* ------------------------------------------------------ */

    constructor(
        uint256 initialSupply,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        _mint(msg.sender, initialSupply);
    }

    /* ------------------------------------------------------ */
    /*                   external functions
    /* ------------------------------------------------------ */

    receive() external payable {
        purchaseTokens(msg.value, address(0));
    }

    /**
     * Fallback function to handle ethereum that was send straight to the contract
     * Unfortunately we cannot use a referral address this way.
     */
    fallback() external payable {
        purchaseTokens(msg.value, address(0));
    }

    /* ------------------------------------------------------ */
    /*                    public funcions              
    /* ------------------------------------------------------ */

    function buy(address _referredBy) public payable returns (uint256) {
        purchaseTokens(msg.value, _referredBy);
    }

    function reinvest() public onlyStronghands {
        // fetch dividends
        uint256 _dividends = myDividends(false); // retrieve ref. bonus later in the code

        // pay out the dividends virtually
        address _customerAddress = msg.sender;
        payoutsTo_[_customerAddress] += (int256)(_dividends * magnitude);

        // retrieve ref. bonus
        _dividends += referralBalance_[_customerAddress];
        referralBalance_[_customerAddress] = 0;

        // dispatch a buy order with the virtualized "withdrawn dividends"
        uint256 _tokens = purchaseTokens(_dividends, address(0));

        // fire event
        emit onReinvestment(_customerAddress, _dividends, _tokens);
    }

    function exit() public {
        // get token count for caller & sell them all
        address _customerAddress = msg.sender;
        uint256 _tokens = tokenBalanceLedger_[_customerAddress];
        if (_tokens > 0) sell(_tokens);

        // lambo delivery service
        withdraw();
    }

    function withdraw() public onlyStronghands {
        // setup data
        address _customerAddress = msg.sender;
        uint256 _dividends = myDividends(false); // get ref. bonus later in the code

        // update dividend tracker
        payoutsTo_[_customerAddress] += (int256)(_dividends * magnitude);

        // add ref. bonus
        _dividends += referralBalance_[_customerAddress];
        referralBalance_[_customerAddress] = 0;

        // lambo delivery service
        payable(_customerAddress).transfer(_dividends);

        // fire event
        emit onWithdraw(_customerAddress, _dividends);
    }

    function myTokens() public view returns (uint256) {
        address _customerAddress = msg.sender;
        return balanceOf(_customerAddress);
    }

    function myDividends(
        bool _includeReferralBonus
    ) public view returns (uint256) {
        address _customerAddress = msg.sender;
        return
            _includeReferralBonus
                ? dividendsOf(_customerAddress) +
                    referralBalance_[_customerAddress]
                : dividendsOf(_customerAddress);
    }

    function dividendsOf(
        address _customerAddress
    ) public view returns (uint256) {
        return
            (uint256)(
                (int256)(
                    profitPerShare_ * tokenBalanceLedger_[_customerAddress]
                ) - payoutsTo_[_customerAddress]
            ) / magnitude;
    }

    /**
     * Retrieve the token balance of any single address.
     */
    function balanceOf(
        address _customerAddress
    ) public view override(ERC20, IPXD) returns (uint256) {
        return tokenBalanceLedger_[_customerAddress];
    }

    /*----------  HELPERS AND CALCULATORS  ----------*/

    function totalEthereumBalance() public view returns (uint) {
        return address(this).balance;
    }

    function sell(uint256 _amountOfTokens) public onlyBagholders {
        // setup data
        address _customerAddress = msg.sender;
        // russian hackers BTFO
        require(_amountOfTokens <= tokenBalanceLedger_[_customerAddress]);
        uint256 _tokens = _amountOfTokens;
        uint256 _ethereum = tokensToEthereum_(_tokens);
        uint256 _dividends = (_ethereum / dividendFee_); // 抽取 10% 手續費
        uint256 _taxedEthereum = (_ethereum - _dividends);

        // burn the sold tokens
        tokenSupply_ = tokenSupply_ - _tokens;
        tokenBalanceLedger_[_customerAddress] -= _tokens;

        // update dividends tracker
        int256 _updatedPayouts = (int256)(
            profitPerShare_ * _tokens + (_taxedEthereum * magnitude)
        );
        payoutsTo_[_customerAddress] -= _updatedPayouts;

        // dividing by zero is a bad idea
        if (tokenSupply_ > 0) {
            // update the amount of dividends per token
            profitPerShare_ =
                profitPerShare_ +
                ((_dividends * magnitude) / tokenSupply_);
        }

        // fire event
        emit onTokenSell(_customerAddress, _tokens, _taxedEthereum);
    }

    function transfer(
        address _toAddress,
        uint256 _amountOfTokens
    ) public override(ERC20, IPXD) onlyBagholders returns (bool) {
        // setup
        address _customerAddress = msg.sender;

        // make sure we have the requested tokens
        // also disables transfers until ambassador phase is over
        // ( we dont want whale premines )
        require(
            !onlyAmbassadors &&
                _amountOfTokens <= tokenBalanceLedger_[_customerAddress]
        );

        // withdraw all outstanding dividends first
        if (myDividends(true) > 0) withdraw();

        // liquify 10% of the tokens that are transfered
        // these are dispersed to shareholders
        uint256 _tokenFee = _amountOfTokens / dividendFee_;
        uint256 _taxedTokens = _amountOfTokens - _tokenFee;
        uint256 _dividends = tokensToEthereum_(_tokenFee);

        // burn the fee tokens
        tokenSupply_ -= _tokenFee;

        // exchange tokens
        tokenBalanceLedger_[_customerAddress] -= _amountOfTokens;
        tokenBalanceLedger_[_toAddress] += _taxedTokens;

        // update dividend trackers
        payoutsTo_[_customerAddress] -= (int256)(
            profitPerShare_ * _amountOfTokens
        );
        payoutsTo_[_toAddress] += (int256)(profitPerShare_ * _taxedTokens);

        // disperse dividends among holders
        profitPerShare_ += (_dividends * magnitude) / tokenSupply_;

        // fire event
        Transfer(_customerAddress, _toAddress, _taxedTokens);

        // ERC20
        return true;
    }

    /* ------------------------------------------------------ */
    /*                   internal functions
    /* ------------------------------------------------------ */

    function purchaseTokens(
        uint256 _incomingEthereum,
        address _referredBy
    ) internal antiEarlyWhale(_incomingEthereum) returns (uint256) {
        // data setup
        address _customerAddress = msg.sender;
        uint256 _undividedDividends = _incomingEthereum / dividendFee_; // 抽取 10% 手續費
        uint256 _referralBonus = _undividedDividends / 3; // 分红三分之一給推薦者
        uint256 _dividends = _undividedDividends - _referralBonus; // 真正属於分红的錢
        uint256 _taxedEthereum = _incomingEthereum - _undividedDividends; // 扣完分红後的钱，用来買幣
        uint256 _amountOfTokens = ethereumToTokens_(_taxedEthereum);
        uint256 _fee = _dividends * magnitude;

        // no point in continuing execution if OP is a poorfag russian hacker
        // prevents overflow in the case that the pyramid somehow magically starts being used by everyone in the world
        // (or hackers)
        // and yes we know that the safemath function automatically rules out the "greater then" equasion.
        require(
            _amountOfTokens > 0 && _amountOfTokens + tokenSupply_ > tokenSupply_
        );

        // is the user referred by a masternode?
        if (
            // is this a referred purchase?
            _referredBy != 0x0000000000000000000000000000000000000000 &&
            // no cheating!
            _referredBy != _customerAddress &&
            // does the referrer have at least X whole tokens?
            // i.e is the referrer a godly chad masternode
            tokenBalanceLedger_[_referredBy] >= stakingRequirement
        ) {
            // wealth redistribution
            referralBalance_[_referredBy] += _referralBonus;
        } else {
            // no ref purchase
            // add the referral bonus back to the global dividends cake
            _dividends += _referralBonus;
            _fee = _dividends * magnitude;
        }

        // we can't give people infinite ethereum
        if (tokenSupply_ > 0) {
            // add tokens to the pool
            tokenSupply_ += _amountOfTokens;

            // take the amount of dividends gained through this transaction, and allocates them evenly to each shareholder
            profitPerShare_ += ((_dividends * magnitude) / (tokenSupply_));

            // calculate the amount of tokens the customer receives over his purchase
            _fee =
                _fee -
                (_fee -
                    (_amountOfTokens *
                        ((_dividends * magnitude) / (tokenSupply_))));
        } else {
            // add tokens to the pool
            tokenSupply_ = _amountOfTokens;
        }

        // update circulating supply & the ledger address for the customer
        tokenBalanceLedger_[_customerAddress] += _amountOfTokens;

        // Tells the contract that the buyer doesn't deserve dividends for the tokens before they owned them;
        //really i know you think you do but you don't
        int256 _updatedPayouts = (int256)(
            (profitPerShare_ * _amountOfTokens) - _fee
        );
        payoutsTo_[_customerAddress] += _updatedPayouts;

        // fire event
        emit onTokenPurchase(
            _customerAddress,
            _incomingEthereum,
            _amountOfTokens,
            _referredBy
        );

        return _amountOfTokens;
    }

    /**
     * Calculate Token price based on an amount of incoming ethereum
     * It's an algorithm, hopefully we gave you the whitepaper with it in scientific notation;
     * Some conversions occurred to prevent decimal errors or underflows / overflows in solidity code.
     */
    function ethereumToTokens_(
        uint256 _ethereum
    ) internal view returns (uint256) {
        uint256 _tokenPriceInitial = tokenPriceInitial_ * 1e18;
        // uint256 _tokensReceived = ((
        //     // underflow attempts BTFO
        //     SafeMath.sub(
        //         (
        //             sqrt(
        //                 (_tokenPriceInitial ** 2) +
        //                     (2 *
        //                         (tokenPriceIncremental_ * 1e18) *
        //                         (_ethereum * 1e18)) +
        //                     (((tokenPriceIncremental_) ** 2) *
        //                         (tokenSupply_ ** 2)) +
        //                     (2 *
        //                         (tokenPriceIncremental_) *
        //                         _tokenPriceInitial *
        //                         tokenSupply_)
        //             )
        //         ),
        //         _tokenPriceInitial
        //     )
        // ) / (tokenPriceIncremental_)) - (tokenSupply_);

        uint256 _tokensReceived = ((// underflow attempts BTFO
        sqrt(
            _tokenPriceInitial ** 2 +
                2 *
                (tokenPriceIncremental_ * 1e18) *
                (_ethereum * 1e18) +
                tokenPriceIncremental_ ** 2 *
                tokenSupply_ ** 2 +
                2 *
                tokenPriceIncremental_ *
                _tokenPriceInitial *
                tokenSupply_
        ) - _tokenPriceInitial) / tokenPriceIncremental_) - tokenSupply_;

        return _tokensReceived;
    }

    /**
     * Calculate token sell value.
     * It's an algorithm, hopefully we gave you the whitepaper with it in scientific notation;
     * Some conversions occurred to prevent decimal errors or underflows / overflows in solidity code.
     */
    function tokensToEthereum_(
        uint256 _tokens
    ) internal view returns (uint256) {
        uint256 tokens_ = (_tokens + 1e18);
        uint256 _tokenSupply = (tokenSupply_ + 1e18);
        uint256 _etherReceived = (// underflow attempts BTFO
        (((tokenPriceInitial_ +
            (tokenPriceIncremental_ * (_tokenSupply / 1e18))) -
            tokenPriceIncremental_) * (tokens_ - 1e18)) -
            (tokenPriceIncremental_ * ((tokens_ ** 2 - tokens_) / 1e18)) /
            2) / 1e18;
        return _etherReceived;
    }
}
