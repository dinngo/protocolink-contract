// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IParam} from './IParam.sol';

interface IAgent {
    error Initialized();

    error InvalidCaller();

    error InvalidBps();

    error UnresetCallback();

    function router() external returns (address);

    function wrappedNative() external returns (address);

    function initialize() external;

    function execute(
        IParam.Logic[] calldata logics,
        address[] calldata tokensReturn,
        bool isFeeEnabled
    ) external payable;
}
