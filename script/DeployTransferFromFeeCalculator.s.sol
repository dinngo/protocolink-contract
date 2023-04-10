// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {TransferFromFeeCalculator} from 'src/fees/TransferFromFeeCalculator.sol';

contract DeployTransferFromFeeCalculator is DeployBase {
    function _run(
        DeployParameters memory params
    ) internal virtual override isRouterAddressZero(params.router) returns (address deployedAddress) {
        deployedAddress = address(
            new TransferFromFeeCalculator(params.router, params.transferFromFeeCalculatorFeeRate)
        );
        console2.log('TransferFromFeeCalculator Deployed:', deployedAddress);
    }
}
