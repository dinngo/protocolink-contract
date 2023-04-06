// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {AaveBorrowFeeCalculator} from 'src/fees/AaveBorrowFeeCalculator.sol';

contract DeployAaveBorrowFeeCalculator is DeployBase {
    function _run(DeployParameters memory params) internal virtual override returns (address deployedAddress) {
        deployedAddress = address(new AaveBorrowFeeCalculator(params.router, params.aaveBorrowFeeCalculatorFeeRate));
        console2.log('AaveBorrowFeeCalculator Deployed:', deployedAddress);
    }
}
