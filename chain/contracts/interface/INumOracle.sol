// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface INumOracle {
    function isAirdrop() external returns (bool);

    function isAirdropNfts() external returns (bool);
}
