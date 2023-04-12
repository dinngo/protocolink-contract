// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {FeeCalculatorBase} from './FeeCalculatorBase.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';
import {IParam} from '../interfaces/IParam.sol';

contract Permit2FeeCalculator is IFeeCalculator, FeeCalculatorBase {
    bytes32 internal constant _META_DATA = bytes32(bytes('permit2:pull-token'));

    constructor(address router, uint256 feeRate) FeeCalculatorBase(router, feeRate) {}

    function getFees(address to, bytes calldata data) external view returns (IParam.Fee[] memory) {
        to;

        // Permit2 transfrom signature:'transferFrom(address,address,uint160,address)', selector:0x36c78516
        (, , uint160 amount, address token) = abi.decode(data[4:], (address, address, uint160, address));

        IParam.Fee[] memory fees = new IParam.Fee[](1);
        fees[0] = IParam.Fee({token: token, amount: calculateFee(uint256(amount)), metadata: _META_DATA});
        return fees;
    }

    function getDataWithFee(bytes calldata data) external view returns (bytes memory) {
        (address from, address to, uint160 amount, address token) = abi.decode(
            data[4:],
            (address, address, uint160, address)
        );
        uint256 amountWithFee = calculateAmountWithFee(amount);
        if (amountWithFee > type(uint160).max) revert('Amount overflow');

        amount = uint160(amountWithFee);
        return abi.encodePacked(data[:4], abi.encode(from, to, amount, token));
    }
}
