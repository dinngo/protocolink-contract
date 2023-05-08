// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {CompoundV3BorrowFeeCalculator} from 'src/fees/CompoundV3BorrowFeeCalculator.sol';

contract DeployCompoundV3BorrowFeeCalculator is DeployBase {
    function _run(
        DeployParameters memory params
    ) internal virtual override isRouterAddressZero(params.router) returns (address deployedAddress) {
        deployedAddress = address(
            new CompoundV3BorrowFeeCalculator(params.router, params.compoundV3BorrowFeeCalculatorFeeRate)
        );
        console2.log('CompoundV3BorrowFeeCalculator Deployed:', deployedAddress);
    }
}
