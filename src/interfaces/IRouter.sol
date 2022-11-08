// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRouter {
    function execute(address tokenIn, uint256 amountIn, address tokenOut, address to, bytes calldata data) external;
}
