// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Agent} from './Agent.sol';
import {IParam} from './interfaces/IParam.sol';
import {IRouter} from './interfaces/IRouter.sol';

/// @title Router executes arbitrary logics
contract Router is IRouter {
    mapping(address => Agent) public agents;
    address public user;

    address private constant _INIT_USER = address(1);

    constructor() {
        user = _INIT_USER;
    }

    function newAgent() public returns (address) {
        // TODO: Check if new user
        Agent agent = new Agent();
        agents[msg.sender] = agent;
        return address(agent);
    }

    /// @notice Execute logics and return tokens to user
    function execute(IParam.Logic[] calldata logics, address[] calldata tokensReturn) external payable {
        if (user == _INIT_USER) {
            user = msg.sender;
        } else {
            revert();
        }

        agents[user].execute(logics, tokensReturn);

        user = _INIT_USER;
    }

    function getAgent() external view returns (address) {
        return address(agents[user]);
    }
}
