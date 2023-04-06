// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {AaveFlashLoanFeeCalculator} from 'src/fees/AaveFlashLoanFeeCalculator.sol';

contract DeployAaveFlashLoanFeeCalculator is DeployBase {
    function _run(DeployParameters memory params) internal virtual override returns (address deployedAddress) {
        deployedAddress = address(
            new AaveFlashLoanFeeCalculator(params.router, params.aaveFlashLoanFeeCalculatorFeeRate)
        );
        console2.log('AaveFlashLoanFeeCalculator Deployed:', deployedAddress);
    }
}
