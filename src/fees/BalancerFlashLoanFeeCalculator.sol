// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {FeeCalculatorBase} from './FeeCalculatorBase.sol';
import {Router} from '../Router.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';
import {IParam} from '../interfaces/IParam.sol';

contract BalancerFlashLoanFeeCalculator is IFeeCalculator, FeeCalculatorBase {
    bytes32 internal constant _META_DATA = bytes32(bytes('balancer-v2:flash-loan'));

    constructor(address router_, uint256 feeRate_) FeeCalculatorBase(router_, feeRate_) {}

    function getFees(address to, bytes calldata data) external view returns (IParam.Fee[] memory) {
        to;

        // Balancer flash loan signature:'flashLoan(address,address[],uint256[],bytes)', selector: 0x5c38449e
        (, address[] memory tokens, uint256[] memory amounts, bytes memory userData) = abi.decode(
            data[4:],
            (address, address[], uint256[], bytes)
        );

        amounts = calculateFee(amounts);

        IParam.Fee[] memory feesWithFlashLoan = _createFees(tokens, amounts, _META_DATA);

        if (userData.length > 0) {
            // Decode data in the flash loan
            (IParam.Logic[] memory logics, , ) = abi.decode(userData, (IParam.Logic[], IParam.Fee[], address[]));

            // Get fees
            IParam.Fee[] memory feesInFlashLoanData = Router(router).getFeesByLogics(logics, 0);

            if (feesInFlashLoanData.length > 0) {
                feesWithFlashLoan = _concatenateFees(feesWithFlashLoan, feesInFlashLoanData);
            }
        }

        return feesWithFlashLoan;
    }

    function getDataWithFee(bytes calldata data) external view returns (bytes memory) {
        (address recipient, address[] memory tokens, uint256[] memory amounts, bytes memory userData) = abi.decode(
            data[4:],
            (address, address[], uint256[], bytes)
        );

        if (userData.length > 0) {
            // Decode data in the flash loan
            (IParam.Logic[] memory logics, IParam.Fee[] memory fees, address[] memory tokensReturn) = abi.decode(
                userData,
                (IParam.Logic[], IParam.Fee[], address[])
            );

            // Update logics
            logics = Router(router).getLogicsDataWithFee(logics);

            // encode
            userData = abi.encode(logics, fees, tokensReturn);
        }

        amounts = calculateAmountWithFee(amounts);
        return abi.encodePacked(data[:4], abi.encode(recipient, tokens, amounts, userData));
    }

    function _createFees(
        address[] memory tokens,
        uint256[] memory amounts,
        bytes32 metadata
    ) internal pure returns (IParam.Fee[] memory) {
        uint256 length = tokens.length;
        IParam.Fee[] memory fees = new IParam.Fee[](length);
        for (uint256 i = 0; i < length; ) {
            fees[i] = IParam.Fee({token: tokens[i], amount: amounts[i], metadata: metadata});

            unchecked {
                ++i;
            }
        }
        return fees;
    }

    function _concatenateFees(
        IParam.Fee[] memory fees1,
        IParam.Fee[] memory fees2
    ) internal pure returns (IParam.Fee[] memory) {
        uint256 length1 = fees1.length;
        uint256 length2 = fees2.length;
        IParam.Fee[] memory totalFees = new IParam.Fee[](length1 + length2);

        for (uint256 i = 0; i < length1; ) {
            totalFees[i] = fees1[i];
            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < length2; ) {
            totalFees[length1 + i] = fees2[i];
            unchecked {
                ++i;
            }
        }

        return totalFees;
    }
}
