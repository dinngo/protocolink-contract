// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IParam2} from './IParam2.sol';

interface IAgent2 {
    event AmountReplaced(uint256 i, uint256 j, uint256 amount);

    event FeeCharged(address indexed token, uint256 amount, bytes32 metadata);

    error InvalidCaller();

    error Initialized();

    error InvalidBps();

    error UnresetCallback();

    function router() external returns (address);

    function wrappedNative() external returns (address);

    function initialize() external;

    function execute(
        IParam2.Logic[] calldata logics,
        IParam2.Fee[] calldata fees,
        address[] calldata tokensReturn
    ) external payable;
}
