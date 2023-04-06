// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {AgentImplementation} from 'src/AgentImplementation.sol';

contract DeployAgentImplementation is DeployBase {
    function _run(DeployParameters memory params) internal virtual override returns (address deployedAddress) {
        deployedAddress = address(new AgentImplementation(params.wrappedNative));
        console2.log('AgentImplementation Deployed:', deployedAddress);
    }
}
