// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRouter {
    struct Logic {
        address to;
        AmountInConfig[] configs;
        bytes data;
    }

    struct AmountInConfig {
        address tokenIn;
        uint256 tokenInBalanceRatio; // Base is 1e18. e.g. 0.7*1e18 means that amountIn is 70% balance of tokenIn.
        uint256 amountInOffset; // The byte offset of amount in Logic.data that will be replaced with balance.
    }

    function msgSender() external returns (address);

    function execute(address[] calldata tokensOut, uint256[] calldata amountsOutMin, Logic[] calldata logics)
        external;
}
