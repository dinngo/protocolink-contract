// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {FeeCalculatorBase} from './FeeCalculatorBase.sol';
import {Router} from '../Router.sol';
import {IAaveV3Provider} from '../interfaces/aaveV3/IAaveV3Provider.sol';
import {IFeeCalculator} from '../interfaces/fees/IFeeCalculator.sol';
import {IParam} from '../interfaces/IParam.sol';

/// @title Aave flash loan fee calculator
contract AaveFlashLoanFeeCalculator is IFeeCalculator, FeeCalculatorBase {
    bytes32 internal constant _V2_FLASH_LOAN_META_DATA = bytes32(bytes('aave-v2:flash-loan'));
    bytes32 internal constant _V3_FLASH_LOAN_META_DATA = bytes32(bytes('aave-v3:flash-loan'));

    address public immutable aaveV3Provider;

    constructor(address router_, uint256 feeRate_, address aaveV3Provider_) FeeCalculatorBase(router_, feeRate_) {
        aaveV3Provider = aaveV3Provider_;
    }

    function getFees(address to, bytes calldata data) external view returns (IParam.Fee[] memory) {
        // Aave flash loan signature:'flashLoan(address,address[],uint256[],uint256[],address,bytes,uint16)', selector: 0xab9c4b5d
        (, address[] memory tokens, uint256[] memory amounts, , , , ) = abi.decode(
            data[4:],
            (address, address[], uint256[], uint256[], address, bytes, uint16)
        );

        bytes32 metadata = to == IAaveV3Provider(aaveV3Provider).getPool()
            ? _V3_FLASH_LOAN_META_DATA
            : _V2_FLASH_LOAN_META_DATA;

        uint256 length = tokens.length;
        IParam.Fee[] memory fees = new IParam.Fee[](length);
        for (uint256 i; i < length; ) {
            fees[i] = IParam.Fee({token: tokens[i], amount: calculateFee(amounts[i]), metadata: metadata});

            unchecked {
                ++i;
            }
        }

        return fees;
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
            // Decode data in the flash loan
            IParam.Logic[] memory logics = abi.decode(params, (IParam.Logic[]));

            // Update logics
            logics = Router(router).getLogicsWithFee(logics);

            // encode
            params = abi.encode(logics);
        }

        amounts = calculateAmountWithFee(amounts);
        return
            abi.encodePacked(
                data[:4],
                abi.encode(receiverAddress, assets, amounts, modes, onBehalfOf, params, referralCode)
            );
    }
}
