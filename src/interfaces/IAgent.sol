// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IParam} from './IParam.sol';

interface IAgent {
    error Initialized();

    error InvalidCaller();

    error InvalidBps();

    error UnresetCallback();

    function initialize() external;

    // For tests file compile succ
    function execute(IParam.Logic[] calldata logics, address[] calldata tokensReturn) external payable;

    // For tests file compile succ
    function executeWithFee(
        IParam.Logic[] calldata logics,
        IParam.Fee[] calldata fees,
        address[] calldata tokensReturn
    ) external payable;
}
