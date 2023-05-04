// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployRouter} from './DeployRouter.s.sol';
import {DeployAaveV2FlashLoanCallback} from './DeployAaveV2FlashLoanCallback.s.sol';
import {DeployAaveV3FlashLoanCallback} from './DeployAaveV3FlashLoanCallback.s.sol';
import {DeployBalancerV2FlashLoanCallback} from './DeployBalancerV2FlashLoanCallback.s.sol';
import {DeployMakerUtility} from './DeployMakerUtility.s.sol';
import {DeployAaveBorrowFeeCalculator} from './DeployAaveBorrowFeeCalculator.s.sol';
import {DeployAaveFlashLoanFeeCalculator} from './DeployAaveFlashLoanFeeCalculator.s.sol';
import {DeployMakerDrawFeeCalculator} from './DeployMakerDrawFeeCalculator.s.sol';
import {DeployNativeFeeCalculator} from './DeployNativeFeeCalculator.s.sol';
import {DeployPermit2FeeCalculator} from './DeployPermit2FeeCalculator.s.sol';
import {DeployTransferFromFeeCalculator} from './DeployTransferFromFeeCalculator.s.sol';
import {DeployCompoundBorrowFeeCalculator} from './DeployCompoundBorrowFeeCalculator.s.sol';

contract DeployAll is
    DeployRouter,
    DeployAaveV2FlashLoanCallback,
    DeployAaveV3FlashLoanCallback,
    DeployBalancerV2FlashLoanCallback,
    DeployMakerUtility,
    DeployAaveBorrowFeeCalculator,
    DeployAaveFlashLoanFeeCalculator,
    DeployMakerDrawFeeCalculator,
    DeployNativeFeeCalculator,
    DeployPermit2FeeCalculator,
    DeployTransferFromFeeCalculator,
    DeployCompoundBorrowFeeCalculator
{
    function _run(
        DeployParameters memory params
    )
        internal
        override(
            DeployRouter,
            DeployAaveV2FlashLoanCallback,
            DeployAaveV3FlashLoanCallback,
            DeployBalancerV2FlashLoanCallback,
            DeployMakerUtility,
            DeployAaveBorrowFeeCalculator,
            DeployAaveFlashLoanFeeCalculator,
            DeployMakerDrawFeeCalculator,
            DeployNativeFeeCalculator,
            DeployPermit2FeeCalculator,
            DeployTransferFromFeeCalculator,
            DeployCompoundBorrowFeeCalculator
        )
        returns (address deployedAddress)
    {
        // router
        deployedAddress = params.router = DeployRouter._run(params);

        // callback
        DeployAaveV2FlashLoanCallback._run(params);
        DeployAaveV3FlashLoanCallback._run(params);
        DeployBalancerV2FlashLoanCallback._run(params);

        // utility
        DeployMakerUtility._run(params);

        // fee
        DeployAaveBorrowFeeCalculator._run(params);
        DeployAaveFlashLoanFeeCalculator._run(params);
        DeployMakerDrawFeeCalculator._run(params);
        DeployNativeFeeCalculator._run(params);
        DeployPermit2FeeCalculator._run(params);
        DeployTransferFromFeeCalculator._run(params);
        DeployCompoundBorrowFeeCalculator._run(params);
    }
}
