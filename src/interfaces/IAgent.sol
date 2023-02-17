// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IParam} from './IParam.sol';

interface IAgent {
    error InvalidCallback();

    error LengthMismatch();

    error InvalidERC20Sig();

    error InvalidBps();

    error UnresetCallback();

    error InsufficientBalance(address tokenReturn, uint256 amountOutMin, uint256 balance);

    function execute(IParam.Logic[] calldata logics, address[] calldata tokensReturn) external payable;
}
