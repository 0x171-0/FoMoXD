// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library PXDEthCalc {
    /// @dev 最一開始的價格
    uint256 internal constant tokenPriceInitial_ = 0.0000001 ether;

    /// @dev 隨著 total supply 變多，PXD 價格會上漲
    uint256 internal constant tokenPriceIncremental_ = 0.00000001 ether;

    /**
     * Calculate Token price based on an amount of incoming ethereum
     * It's an algorithm, hopefully we gave you the whitepaper with it in scientific notation;
     * Some conversions occurred to prevent decimal errors or underflows / overflows in solidity code.
     */
    function ethereumToTokens_(
        uint256 _ethereum,
        uint256 tokenSupply_
    ) internal view returns (uint256) {
        uint256 _tokenPriceInitial = tokenPriceInitial_ * 1e18;

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
        uint256 _tokens,
        uint256 tokenSupply_
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

    function sqrt(uint256 x) public pure returns (uint256 y) {
        uint256 z = (((x + 1)) / 2);
        y = x;
        while (z < y) {
            y = z;
            z = ((((x / z) + z)) / 2);
        }
    }
}
