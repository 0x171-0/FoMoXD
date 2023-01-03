// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./event/EPXD.sol";

import "./interface/IPXD.sol";

import "./library/PXDEthCalc.sol";

contract PXD is ERC20, EPXD, IPXD {
    /* ------------------------------------------------------ */
    /*                      CONFIGURABLES                     */
    /* ------------------------------------------------------ */
    uint8 internal constant dividendFee_ = 10; // 買賣幣都會抽取 10% 手續費

    uint256 internal constant magnitude = 2 ** 64;

    // proof of stake (defaults at 100 tokens)
    uint256 public stakingRequirement = 100e18;

    // ambassador program
    mapping(address => bool) internal ambassadors_;

    // 大使最多可以購買的上限額度
    uint256 internal constant ambassadorMaxPurchase_ = 1 ether;
    // 推薦人額度
    uint256 internal constant ambassadorQuota_ = 20 ether;
    /* ------------------------------------------------------ */
    /*                        DATASETS                        */
    /* ------------------------------------------------------ */
    // amount of shares for each address (scaled number)
    // user -> PXD balance
    mapping(address => uint256) internal _balances;
    // referral -> 分潤
    mapping(address => uint256) internal referralBalance_;
    // user -> 已提取分潤表
    mapping(address => int256) internal payoutsTo_;

    mapping(address => uint256) internal ambassadorAccumulatedQuota_;

    uint256 internal tokenSupply_ = 0;

    // 總體分潤
    uint256 internal profitPerShare_;

    // administrator list (see above on what they can do)
    // 管理員列表
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
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {}

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
        // 更新已提取分紅
        payoutsTo_[_customerAddress] += (int256)(_dividends * magnitude);

        // retrieve ref. bonus
        // 獲取推薦獎勵
        _dividends += referralBalance_[_customerAddress];
        referralBalance_[_customerAddress] = 0;

        // dispatch a buy order with the virtualized "withdrawn dividends"
        // 拿既有的 ETH 分紅購買 PXD
        uint256 _tokens = purchaseTokens(_dividends, address(0));

        // fire event
        emit onReinvestment(_customerAddress, _dividends, _tokens);
    }

    function exit() public {
        // get token count for caller & sell them all
        address _customerAddress = msg.sender;
        // 獲取 PXD 數量
        uint256 _tokens = _balances[_customerAddress];
        // 全數賣出 PXD
        if (_tokens > 0) sell(_tokens);

        // lambo delivery service
        // 提取全部 ETH 份額
        withdraw();
    }

    function withdraw() public onlyStronghands {
        // setup data
        address _customerAddress = msg.sender;
        uint256 _dividends = myDividends(false); // get ref. bonus later in the code

        // update dividend tracker
        // 更新使用者已提取分潤
        payoutsTo_[_customerAddress] += (int256)(_dividends * magnitude);

        // add ref. bonus
        _dividends += referralBalance_[_customerAddress];
        referralBalance_[_customerAddress] = 0;

        // lambo delivery service
        payable(_customerAddress).transfer(_dividends);

        // fire event
        emit onWithdraw(_customerAddress, _dividends);
    }

    function sell(uint256 _amountOfTokens) public onlyBagholders {
        // setup data
        address _customerAddress = msg.sender;
        // russian hackers BTFO
        require(_amountOfTokens <= _balances[_customerAddress]);

        uint256 _tokens = _amountOfTokens;
        uint256 _ethereum = PXDEthCalc.tokensToEthereum_(_tokens, tokenSupply_);

        uint256 _dividends = (_ethereum / dividendFee_); // 抽取 10% 分潤
        uint256 _taxedEthereum = (_ethereum - _dividends);

        // burn the sold tokens
        tokenSupply_ = tokenSupply_ - _tokens;
        _balances[_customerAddress] -= _tokens;

        // update dividends tracker
        int256 _updatedPayouts = (int256)(
            profitPerShare_ * _tokens + (_taxedEthereum * magnitude)
        );
        // 減少使用者已提取分潤額，代表 user devide 增多，可以 withdraw 數量更多了
        // userDevide = totalProfitPerShare_ - payoutsToUser
        payoutsTo_[_customerAddress] -= _updatedPayouts;

        // dividing by zero is a bad idea
        if (tokenSupply_ > 0) {
            // update the amount of dividends per token
            // 把分潤分給所有持有人
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
        // 檢驗餘額大於等於轉帳數量
        require(
            !onlyAmbassadors && _amountOfTokens <= _balances[_customerAddress]
        );

        // withdraw all outstanding dividends first
        // 如果有分潤就提現
        if (myDividends(true) > 0) withdraw();

        // liquify 10% of the tokens that are transfered
        // these are dispersed to shareholders
        // 手續費
        uint256 _tokenFee = _amountOfTokens / dividendFee_;
        // 扣除手續費後得到的 PXD 股權
        uint256 _taxedTokens = _amountOfTokens - _tokenFee;

        uint256 _dividends = PXDEthCalc.tokensToEthereum_(
            _tokenFee,
            tokenSupply_
        );

        // burn the fee tokens

        tokenSupply_ -= _tokenFee;

        // exchange tokens
        _balances[_customerAddress] -= _amountOfTokens;
        _balances[_toAddress] += _taxedTokens;

        // update dividend trackers
        payoutsTo_[_customerAddress] -= (int256)(
            profitPerShare_ * _amountOfTokens
        );
        payoutsTo_[_toAddress] += (int256)(profitPerShare_ * _taxedTokens);

        // disperse dividends among holders
        // 手續費計算進分紅
        profitPerShare_ += (_dividends * magnitude) / tokenSupply_;

        // fire event
        emit Transfer(_customerAddress, _toAddress, _taxedTokens);

        // ERC20
        return true;
    }

    /*----------  HELPERS AND CALCULATORS  ----------*/

    function totalEthereumBalance() public view returns (uint) {
        // 合約總餘額
        return address(this).balance;
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
        // 根據現有的 PXD 持有數計算出可以領得的份額 - 扣掉已提取的份額
        return
            (uint256)(
                (int256)(profitPerShare_ * _balances[_customerAddress]) -
                    payoutsTo_[_customerAddress]
            ) / magnitude;
    }

    /**
     * Retrieve the token balance of any single address.
     */
    function balanceOf(
        address _customerAddress
    ) public view override(ERC20, IPXD) returns (uint256) {
        return _balances[_customerAddress];
    }

    /*----------  ADMINISTRATOR ONLY FUNCTIONS  ----------*/
    // 设置
    function disableInitialStage() public onlyAdministrator {
        onlyAmbassadors = false;
    }

    function setAdministrator(
        bytes32 _identifier,
        bool _status
    ) public onlyAdministrator {
        administrators[_identifier] = _status;
    }

    function setStakingRequirement(
        uint256 _amountOfTokens
    ) public onlyAdministrator {
        stakingRequirement = _amountOfTokens;
    }

    /* ------------------------------------------------------ */
    /*                   internal functions
    /* ------------------------------------------------------ */

    function purchaseTokens(
        uint256 _incomingEthereum,
        address _referredBy // 推薦人
    ) internal antiEarlyWhale(_incomingEthereum) returns (uint256) {
        // data setup
        address _customerAddress = msg.sender;
        // 抽取 10% ETH 分紅
        uint256 _undividedDividends = _incomingEthereum / dividendFee_;
        // 分红三分之一 ETH 給推薦者
        uint256 _referralBonus = _undividedDividends / 3;
        // 扣除給推薦者 ETH 後剩下的分紅
        uint256 _dividends = _undividedDividends - _referralBonus;
        // 分紅完剩下的資金
        uint256 _taxedEthereum = _incomingEthereum - _undividedDividends;
        // 拿剩下的資金買幣
        uint256 _amountOfTokens = PXDEthCalc.ethereumToTokens_(
            _taxedEthereum,
            tokenSupply_
        );

        uint256 _fee = _dividends * magnitude; // 總分潤

        // no point in continuing execution if OP is a poorfag russian hacker
        // prevents overflow in the case that the pyramid somehow magically starts being used by everyone in the world
        // (or hackers)
        // and yes we know that the safemath function automatically rules out the "greater then" equasion.
        require(
            _amountOfTokens > 0 && _amountOfTokens + tokenSupply_ > tokenSupply_
        );

        // 如果有推薦者，則推薦獎金歸推薦者；如果沒有推薦者，則推薦獎金歸給使用者自己
        // is the user referred by a masternode?
        if (
            // is this a referred purchase?
            _referredBy != 0x0000000000000000000000000000000000000000 &&
            // no cheating! 推薦人不能是自己
            _referredBy != _customerAddress &&
            // does the referrer have at least X whole tokens?
            // i.e is the referrer a godly chad masternode
            _balances[_referredBy] >= stakingRequirement
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
        // 已有人持股
        if (tokenSupply_ > 0) {
            // add tokens to the pool
            tokenSupply_ += _amountOfTokens;

            // take the amount of dividends gained through this transaction, and allocates them evenly to each shareholder
            // 分潤給 PXD 持有者
            profitPerShare_ += ((_dividends * magnitude) / (tokenSupply_));

            // calculate the amount of tokens the customer receives over his purchase
            _fee =
                _fee -
                (_fee -
                    (_amountOfTokens *
                        ((_dividends * magnitude) / (tokenSupply_))));
        } else {
            // 無人持股
            // add tokens to the pool
            tokenSupply_ = _amountOfTokens;
        }

        // update circulating supply & the ledger address for the customer
        // 將這次購買的數量夾到使用者帳戶
        _balances[_customerAddress] += _amountOfTokens;

        // Tells the contract that the buyer doesn't deserve dividends for the tokens before they owned them;
        //really i know you think you do but you don't
        // 計算 user 的分潤，扣除掉這次購買的分潤
        int256 _updatedPayouts = (int256)(
            (profitPerShare_ * _amountOfTokens) - _fee
        );
        // 更新使用者已提取分潤
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
}
