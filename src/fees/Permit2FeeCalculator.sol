// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FeeBase} from './FeeBase.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';

contract Permit2FeeCalculator is IFeeCalculator, FeeBase {
    constructor(address router, uint256 feeRate) FeeBase(router, feeRate) {}

    function getFee(bytes calldata data) external view returns (address, uint256) {
        (, , uint160 amount, address token) = abi.decode(data, (address, address, uint160, address));
        return (token, calculateFee(uint256(amount)));
    }

    function getDataWithFee(bytes calldata data) external view returns (bytes memory) {
        (address from, address to, uint160 amount, address token) = abi.decode(
            data,
            (address, address, uint160, address)
        );
        amount = uint160(calculateAmountWithFee(amount));
        return abi.encode(from, to, amount, token);
    }
}
