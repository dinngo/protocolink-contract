// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AgentImplementation} from './AgentImplementation.sol';
import {IAgent, Agent} from './Agent.sol';
import {IParam} from './interfaces/IParam.sol';
import {IRouter} from './interfaces/IRouter.sol';

/// @title Router executes arbitrary logics
contract Router is IRouter {
    mapping(address => IAgent) public agents;
    address public user;

    address private constant _INIT_USER = address(1);

    address public immutable agentImplementation;

    modifier checkCaller() {
        if (user == _INIT_USER) {
            user = msg.sender;
        } else {
            revert();
        }
        _;
        user = _INIT_USER;
    }

    constructor() {
        user = _INIT_USER;
        agentImplementation = address(new AgentImplementation());
    }

    function newAgent() public returns (address payable) {
        if (address(agents[msg.sender]) != address(0)) {
            revert();
        } else {
            address owner = msg.sender;
            IAgent agent = IAgent(address(new Agent{salt: bytes32(bytes20((uint160(owner))))}(agentImplementation)));
            agent.initialize(owner);
            agents[owner] = agent;
            return payable(address(agent));
        }
    }

    /// @notice Execute logics and return tokens to user
    function execute(IParam.Logic[] calldata logics, address[] calldata tokensReturn) external payable checkCaller {
        IAgent agent = agents[user];

        if (address(agent) == address(0)) {
            agent = IAgent(newAgent());
        }

        agent.execute{value: msg.value}(logics, tokensReturn);
    }

    function getAgent() external view returns (address) {
        return address(agents[user]);
    }

    function getAgent(address owner) external view returns (address) {
        return address(agents[owner]);
    }

    function calcAgent(address owner) external view returns (address) {
        address result = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            bytes32(bytes20((uint160(owner)))),
                            keccak256(abi.encodePacked(type(Agent).creationCode, abi.encode(agentImplementation)))
                        )
                    )
                )
            )
        );
        return result;
    }
}
