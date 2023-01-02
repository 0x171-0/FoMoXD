// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IPXD {
    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    function stakingRequirement() external view returns (uint256);

    /**
     * @dev Converts all incoming ethereum to tokens for the caller, and passes down the referral addy (if any)
     * 買時 = 用 ETH 換鑄造代幣
     */
    function buy(address _referredBy) external payable returns (uint256);

    /**
     * Alias of sell() and withdraw().
     */
    function exit() external;

    /**
     * @dev Liquifies tokens to ethereum.
     * 賣幣 = 銷毀代幣換 ETH
     */
    function sell(uint256 _amountOfTokens) external;

    /**
     * Retrieve the tokens owned by the caller.
     */
    function myTokens() external view returns (uint256);

    /**
     * Retrieve the dividends owned by the caller.
     * If `_includeReferralBonus` is to to 1/true, the referral bonus will be included in the calculations.
     * The reason for this, is that in the frontend, we will want to get the total divs (global + ref)
     * But in the internal calculations, we want them separate.
     */
    function myDividends(
        bool _includeReferralBonus
    ) external view returns (uint256);

    /**
     * Transfer tokens from the caller to a new holder.
     * Remember, there's a 10% fee here as well.
     */
    function transfer(
        address _toAddress,
        uint256 _amountOfTokens
    ) external returns (bool);

    /**
     * Retrieve the dividend balance of any single address.
     */
    function dividendsOf(
        address _customerAddress
    ) external view returns (uint256);

    /**
     * Converts all of caller's dividends to tokens.
     * 使用既有的分紅繼續購買 PXD Token
     */
    function reinvest() external;

    /**
     * Withdraws all of the callers earnings.
     */
    function withdraw() external;

    /**
     * Method to view the current Ethereum stored in the contract
     * Example: totalEthereumBalance()
     */
    function totalEthereumBalance() external view returns (uint);
}
