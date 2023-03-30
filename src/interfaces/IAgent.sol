// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IParam} from './IParam.sol';

interface IAgent {
    event AmountReplaced(uint256 i, uint256 j, uint256 amount);

    error InvalidCaller();

    error Initialized();

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
