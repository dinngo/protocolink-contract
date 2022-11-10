// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRouter {
    struct Logic {
        address to;
        address token;
        uint256 amountOffset; // Byte offset in data
        bytes data;
    }

    function execute(address tokenIn, uint256 amountIn, address tokenOut, uint256 amountOutMin, Logic[] calldata logics)
        external;
}
