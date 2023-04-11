// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployRouter} from './DeployRouter.s.sol';
import {DeployFlashLoanCallbackAaveV2} from './DeployFlashLoanCallbackAaveV2.s.sol';
import {DeployFlashLoanCallbackAaveV3} from './DeployFlashLoanCallbackAaveV3.s.sol';
import {DeployFlashLoanCallbackBalancerV2} from './DeployFlashLoanCallbackBalancerV2.s.sol';
import {DeployUtilityMaker} from './DeployUtilityMaker.s.sol';
import {DeployAaveBorrowFeeCalculator} from './DeployAaveBorrowFeeCalculator.s.sol';
import {DeployAaveFlashLoanFeeCalculator} from './DeployAaveFlashLoanFeeCalculator.s.sol';
import {DeployMakerDrawFeeCalculator} from './DeployMakerDrawFeeCalculator.s.sol';
import {DeployNativeFeeCalculator} from './DeployNativeFeeCalculator.s.sol';
import {DeployPermit2FeeCalculator} from './DeployPermit2FeeCalculator.s.sol';
import {DeployTransferFromFeeCalculator} from './DeployTransferFromFeeCalculator.s.sol';

contract DeployAll is
    DeployRouter,
    DeployFlashLoanCallbackAaveV2,
    DeployFlashLoanCallbackAaveV3,
    DeployFlashLoanCallbackBalancerV2,
    DeployUtilityMaker,
    DeployAaveBorrowFeeCalculator,
    DeployAaveFlashLoanFeeCalculator,
    DeployMakerDrawFeeCalculator,
    DeployNativeFeeCalculator,
    DeployPermit2FeeCalculator,
    DeployTransferFromFeeCalculator
{
    function _run(
        DeployParameters memory params
    )
        internal
        override(
            DeployRouter,
            DeployFlashLoanCallbackAaveV2,
            DeployFlashLoanCallbackAaveV3,
            DeployFlashLoanCallbackBalancerV2,
            DeployUtilityMaker,
            DeployAaveBorrowFeeCalculator,
            DeployAaveFlashLoanFeeCalculator,
            DeployMakerDrawFeeCalculator,
            DeployNativeFeeCalculator,
            DeployPermit2FeeCalculator,
            DeployTransferFromFeeCalculator
        )
        returns (address deployedAddress)
    {
        // router
        deployedAddress = params.router = DeployRouter._run(params);

        // callback
        DeployFlashLoanCallbackAaveV2._run(params);
        DeployFlashLoanCallbackAaveV3._run(params);
        DeployFlashLoanCallbackBalancerV2._run(params);

        // utility
        DeployUtilityMaker._run(params);

        // fee
        DeployAaveBorrowFeeCalculator._run(params);
        DeployAaveFlashLoanFeeCalculator._run(params);
        DeployMakerDrawFeeCalculator._run(params);
        DeployNativeFeeCalculator._run(params);
        DeployPermit2FeeCalculator._run(params);
        DeployTransferFromFeeCalculator._run(params);
    }
}
