// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FeeCalculatorBase} from './FeeCalculatorBase.sol';
import {Router} from '../Router.sol';
import {IAaveV3Provider} from '../interfaces/aaveV3/IAaveV3Provider.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';
import {IParam} from '../interfaces/IParam.sol';

contract AaveFlashLoanFeeCalculator is IFeeCalculator, FeeCalculatorBase {
    address private constant _AAVE_V3_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    bytes32 private constant _V2_FLASHLOAN_META_DATA = bytes32(bytes('aave-v2:flashloan'));
    bytes32 private constant _V3_FLASHLOAN_META_DATA = bytes32(bytes('aave-v3:flashloan'));

    constructor(address router, uint256 feeRate) FeeCalculatorBase(router, feeRate) {}

    function getFees(address to, bytes calldata data) external view returns (IParam.Fee[] memory) {
        // Aave flashloan signature:'flashLoan(address,address[],uint256[],uint256[],address,bytes,uint16)', selector: 0xab9c4b5d
        (, address[] memory tokens, uint256[] memory amounts, , , bytes memory params, ) = abi.decode(
            data[4:],
            (address, address[], uint256[], uint256[], address, bytes, uint16)
        );

        amounts = calculateFee(amounts);
        bytes32 metadata = to == IAaveV3Provider(_AAVE_V3_PROVIDER).getPool()
            ? _V3_FLASHLOAN_META_DATA
            : _V2_FLASHLOAN_META_DATA;

        IParam.Fee[] memory feesWithFlashLoan = _createFees(tokens, amounts, metadata);

        if (params.length > 0) {
            // Decode data in the flashLoan
            (IParam.Logic[] memory logics, , ) = abi.decode(params, (IParam.Logic[], IParam.Fee[], address[]));

            // Get fees
            IParam.Fee[] memory feesInFlashLoanData = Router(router).getFeesByLogics(logics, 0);

            if (feesInFlashLoanData.length > 0) {
                feesWithFlashLoan = _concatenateFees(feesWithFlashLoan, feesInFlashLoanData);
            }
        }

        return feesWithFlashLoan;
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
            logics = Router(router).getLogicsDataWithFee(logics);

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

    function _createFees(
        address[] memory tokens,
        uint256[] memory amounts,
        bytes32 metadata
    ) private pure returns (IParam.Fee[] memory) {
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
    ) private pure returns (IParam.Fee[] memory) {
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
