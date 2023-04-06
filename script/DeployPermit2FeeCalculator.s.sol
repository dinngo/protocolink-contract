// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {Permit2FeeCalculator} from 'src/fees/Permit2FeeCalculator.sol';

contract DeployPermit2FeeCalculator is DeployBase {
    function _run(DeployParameters memory params) internal virtual override returns (address deployedAddress) {
        deployedAddress = address(new Permit2FeeCalculator(params.router, params.permit2FeeCalculatorFeeRate));
        console2.log('Permit2FeeCalculator Deployed:', deployedAddress);
    }
}
