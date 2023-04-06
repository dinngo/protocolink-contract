// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {MakerDrawFeeCalculator} from 'src/fees/MakerDrawFeeCalculator.sol';

contract DeployMakerDrawFeeCalculator is DeployBase {
    function _run(DeployParameters memory params) internal virtual override returns (address deployedAddress) {
        deployedAddress = address(
            new MakerDrawFeeCalculator(params.router, params.makerDrawFeeCalculatorFeeRate, params.dai)
        );
        console2.log('MakerDrawFeeCalculator Deployed:', deployedAddress);
    }
}
