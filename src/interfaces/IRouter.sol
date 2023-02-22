// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IParam} from './IParam.sol';

interface IRouter {
    function agentImplementation() external view returns (address);

    function user() external view returns (address);

    function getAgent() external view returns (address);

    function getUserAgent() external view returns (address, address);

    function getAgent(address user) external view returns (address);

    function calcAgent(address user) external view returns (address);

    function newAgent() external returns (address payable);

    function newAgentFor(address user) external returns (address payable);

    function execute(IParam.Logic[] calldata logics, address[] calldata tokensReturn) external payable;
}
