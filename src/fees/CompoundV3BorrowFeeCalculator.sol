// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {FeeCalculatorBase} from './FeeCalculatorBase.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';
import {IParam} from '../interfaces/IParam.sol';

/// @title Compound V3 borrow fee calculator
contract CompoundV3BorrowFeeCalculator is IFeeCalculator, FeeCalculatorBase {
    bytes32 internal constant _META_DATA = bytes32(bytes('compound-v3:borrow'));

    constructor(address router_, uint256 feeRate_) FeeCalculatorBase(router_, feeRate_) {}

    function getFees(address, bytes calldata data) external view returns (IParam.Fee[] memory) {
        // Compound V3 borrow signature:'withdrawFrom(address,address,address,uint256)', selector:0x26441318
        (, , address asset, uint256 amount) = abi.decode(data[4:], (address, address, address, uint256));

        IParam.Fee[] memory fees = new IParam.Fee[](1);
        fees[0] = IParam.Fee({token: asset, amount: calculateFee(amount), metadata: _META_DATA});
        return fees;
    }

    function getDataWithFee(bytes calldata data) external view returns (bytes memory) {
        (address src, address to, address asset, uint256 amount) = abi.decode(
            data[4:],
            (address, address, address, uint256)
        );
        amount = calculateAmountWithFee(amount);
        return abi.encodePacked(data[:4], abi.encode(src, to, asset, amount));
    }
}
