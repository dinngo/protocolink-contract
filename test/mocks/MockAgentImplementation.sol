// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AgentImplementation} from 'src/AgentImplementation.sol';
import {IMockAgent} from './IMockAgent.sol';

contract MockAgentImplementation is IMockAgent, AgentImplementation {
    constructor(address wrappedNative_) AgentImplementation(wrappedNative_) {}

    function caller() external view returns (address) {
        return _caller;
    }
}
