// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FeeBase} from './FeeBase.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';
import {IRouter} from '../interfaces/IRouter.sol';
import {IParam} from '../interfaces/IParam.sol';

contract AaveFlashLoanFeeCalculator is IFeeCalculator, FeeBase {
    bytes32 private constant _META_DATA = bytes32(bytes('Aave:FlashLoan'));

    constructor(address router, uint256 feeRate) FeeBase(router, feeRate) {}

    function getFees(bytes calldata data) external view returns (address[] memory, uint256[] memory, bytes32) {
        // Aave flashloan signature:'flashLoan(address,address[],uint256[],uint256[],address,bytes,uint16)', selector: 0xab9c4b5d
        (, address[] memory tokens, uint256[] memory amounts, , , bytes memory params, ) = abi.decode(
            data[4:],
            (address, address[], uint256[], uint256[], address, bytes, uint16)
        );

        if (params.length > 0) {
            // Decode data in the flashLoan
            (IParam.Logic[] memory logics, , ) = abi.decode(params, (IParam.Logic[], IParam.Fee[], address[]));

            // Get fees
            IParam.Fee[] memory feesInFlashLoanData = IRouter(router).getFeesByLogics(logics, 0);

            uint256 length = feesInFlashLoanData.length;
            if (length > 0) {
                address[] memory allTokens = _concatenateWithFeesContent(tokens, feesInFlashLoanData);
                uint256[] memory allAmounts = _concatenateWithFeesContent(calculateFee(amounts), feesInFlashLoanData);
                return (allTokens, allAmounts, _META_DATA);
            }
        }

        return (tokens, calculateFee(amounts), _META_DATA);
    }

    function getDataWithFee(bytes calldata data) external view returns (bytes memory) {
        (
            address receiverAddress,
            address[] memory assets,
            uint256[] memory amounts,
            uint256[] memory modes,
            address onBehalfOf,
            bytes memory params,
            uint16 referralCode
        ) = abi.decode(data[4:], (address, address[], uint256[], uint256[], address, bytes, uint16));

        if (params.length > 0) {
            // Decode data in the flashLoan
            (IParam.Logic[] memory logics, IParam.Fee[] memory fees, address[] memory tokensReturn) = abi.decode(
                params,
                (IParam.Logic[], IParam.Fee[], address[])
            );

            // Update logics
            logics = IRouter(router).getLogicsDataWithFee(logics);

            // encode
            params = abi.encode(logics, fees, tokensReturn);
        }

        amounts = calculateAmountWithFee(amounts);
        return
            abi.encodePacked(
                data[:4],
                abi.encode(receiverAddress, assets, amounts, modes, onBehalfOf, params, referralCode)
            );
    }

    function _concatenateWithFeesContent(
        address[] memory arr,
        IParam.Fee[] memory fees
    ) private pure returns (address[] memory) {
        uint256 arrLength = arr.length;
        uint256 feesLength = fees.length;
        address[] memory results = new address[](arrLength + feesLength);

        for (uint256 i = 0; i < arrLength; ) {
            results[i] = arr[i];
            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < feesLength; ) {
            results[arrLength + i] = fees[i].token;
            unchecked {
                ++i;
            }
        }

        return results;
    }

    function _concatenateWithFeesContent(
        uint256[] memory arr,
        IParam.Fee[] memory fees
    ) private pure returns (uint256[] memory) {
        uint256 arrLength = arr.length;
        uint256 feesLength = fees.length;
        uint256[] memory results = new uint256[](arrLength + feesLength);

        for (uint256 i = 0; i < arrLength; ) {
            results[i] = arr[i];
            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < feesLength; ) {
            results[arrLength + i] = fees[i].amount;
            unchecked {
                ++i;
            }
        }

        return results;
    }
}
