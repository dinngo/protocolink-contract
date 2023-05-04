// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {CompoundBorrowFeeCalculator} from 'src/fees/CompoundBorrowFeeCalculator.sol';

contract DeployCompoundBorrowFeeCalculator is DeployBase {
    function _run(
        DeployParameters memory params
    ) internal virtual override isRouterAddressZero(params.router) returns (address deployedAddress) {
        deployedAddress = address(
            new CompoundBorrowFeeCalculator(params.router, params.compoundBorrowFeeCalculatorFeeRate)
        );
        console2.log('CompoundBorrowFeeCalculator Deployed:', deployedAddress);
    }
}
