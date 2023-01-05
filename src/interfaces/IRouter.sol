// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRouter {
    error NotEmptyUser();

    error EmptyUser();

    error LengthMismatch();

    error InsufficientBalance(address tokenOut, uint256 amountOutMin, uint256 balance);

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

    function user() external returns (address);

    function execute(address[] calldata tokensOut, uint256[] calldata amountsOutMin, Logic[] calldata logics)
        external;

    function executeUserSet(address[] calldata tokensOut, uint256[] calldata amountsOutMin, Logic[] calldata logics)
        external;
}
