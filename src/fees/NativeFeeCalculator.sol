// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {FeeCalculatorBase} from './FeeCalculatorBase.sol';
import {IFeeCalculator} from '../interfaces/fees/IFeeCalculator.sol';
import {IParam} from '../interfaces/IParam.sol';

/// @title Native fee calculator
contract NativeFeeCalculator is IFeeCalculator, FeeCalculatorBase {
    bytes32 internal constant _META_DATA = bytes32(bytes('native-token'));
    address internal constant _NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    constructor(address router_, uint256 feeRate_) FeeCalculatorBase(router_, feeRate_) {}

    function getFees(address, bytes calldata data) external view returns (IParam.Fee[] memory) {
        IParam.Fee[] memory fees = new IParam.Fee[](1);
        fees[0] = IParam.Fee({token: _NATIVE, amount: calculateFee(uint256(bytes32(data))), metadata: _META_DATA});
        return fees;
    }

    function getDataWithFee(bytes calldata data) external view returns (bytes memory) {
        return abi.encodePacked(calculateAmountWithFee(uint256(bytes32(data))));
    }
}
