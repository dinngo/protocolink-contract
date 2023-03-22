// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IParam} from './IParam.sol';

interface IAgent {
    error Initialized();

    error InvalidCaller();

    error InvalidBps();

    error UnresetCallback();

    function initialize() external;

    function execute(
        IParam.Logic[] calldata logics,
        address[] calldata tokensReturn,
        bool isFeeEnabled
    ) external payable;
}
