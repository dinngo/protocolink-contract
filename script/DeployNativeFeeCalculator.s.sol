// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {NativeFeeCalculator} from 'src/fees/NativeFeeCalculator.sol';

contract DeployNativeFeeCalculator is DeployBase {
    function _run(
        DeployParameters memory params
    ) internal virtual override isRouterAddressZero(params.router) returns (address deployedAddress) {
        deployedAddress = address(new NativeFeeCalculator(params.router, params.nativeFeeCalculatorFeeRate));
        console2.log('NativeFeeCalculator Deployed:', deployedAddress);
    }
}
