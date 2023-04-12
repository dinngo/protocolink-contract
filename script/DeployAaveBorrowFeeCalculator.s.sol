// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {AaveBorrowFeeCalculator} from 'src/fees/AaveBorrowFeeCalculator.sol';

contract DeployAaveBorrowFeeCalculator is DeployBase {
    function _run(
        DeployParameters memory params
    ) internal virtual override isRouterAddressZero(params.router) returns (address deployedAddress) {
        deployedAddress = address(
            new AaveBorrowFeeCalculator(params.router, params.aaveBorrowFeeCalculatorFeeRate, params.aaveV3Provider)
        );
        console2.log('AaveBorrowFeeCalculator Deployed:', deployedAddress);
    }
}
