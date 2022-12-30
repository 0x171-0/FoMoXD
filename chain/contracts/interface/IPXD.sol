// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IPXD {
    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    function stakingRequirement() external view returns (uint256);

    function buy(address _referredBy) external payable returns (uint256);

    function sell(uint256 _amountOfTokens) external;

    function dividendsOf(
        address _customerAddress
    ) external view returns (uint256);

    function reinvest() external;

    function withdraw() external;
}
