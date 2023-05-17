// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AgentImplementation} from 'src/AgentImplementation.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';

interface IMockAgent is IAgent {
    function INIT_CALLBACK_WITH_CHARGE() external returns (bytes32);

    function callbackWithCharge() external returns (bytes32);
}

contract MockAgentImplementation is IMockAgent, AgentImplementation {
    constructor(address wrappedNative_) AgentImplementation(wrappedNative_) {}

    function INIT_CALLBACK_WITH_CHARGE() external pure returns (bytes32) {
        return _INIT_CALLBACK_WITH_CHARGE;
    }

    function callbackWithCharge() external view returns (bytes32) {
        return _callbackWithCharge;
    }
}
