// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAgent} from 'src/interfaces/IAgent.sol';

interface IMockAgent is IAgent {
    function caller() external returns (address);
}
