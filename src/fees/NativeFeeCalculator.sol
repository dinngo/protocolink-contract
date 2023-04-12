// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FeeCalculatorBase} from './FeeCalculatorBase.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';
import {IParam} from '../interfaces/IParam.sol';

contract NativeFeeCalculator is IFeeCalculator, FeeCalculatorBase {
    bytes32 internal constant _META_DATA = bytes32(bytes('native-token'));
    address internal constant _NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    constructor(address router, uint256 feeRate) FeeCalculatorBase(router, feeRate) {}

    function getFees(address to, bytes calldata data) external view returns (IParam.Fee[] memory) {
        to;

        IParam.Fee[] memory fees = new IParam.Fee[](1);
        fees[0] = IParam.Fee({token: _NATIVE, amount: calculateFee(uint256(bytes32(data))), metadata: _META_DATA});
        return fees;
    }

    function getDataWithFee(bytes calldata data) external view returns (bytes memory) {
        return abi.encodePacked(calculateAmountWithFee(uint256(bytes32(data))));
    }
}
