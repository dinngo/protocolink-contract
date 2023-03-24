// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FeeBase} from './FeeBase.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';

contract Permit2FeeCalculator is IFeeCalculator, FeeBase {
    constructor(address router, uint256 feeRate) FeeBase(router, feeRate) {}

    function getFees(bytes calldata data) external view returns (address[] memory, uint256[] memory) {
        // Permit2 transfrom signature:'transferFrom(address,address,uint160,address)', selector:0x36c78516
        (, , uint160 amount, address token) = abi.decode(data, (address, address, uint160, address));

        address[] memory tokens = new address[](1);
        tokens[0] = token;

        uint256[] memory fees = new uint256[](1);
        fees[0] = calculateFee(uint256(amount));
        return (tokens, fees);
    }

    function getDataWithFee(bytes calldata data) external view returns (bytes memory) {
        (address from, address to, uint160 amount, address token) = abi.decode(
            data,
            (address, address, uint160, address)
        );
        uint256 amountWithFee = calculateAmountWithFee(amount);
        if (amountWithFee > type(uint160).max) revert('Amount overflow');

        amount = uint160(amountWithFee);
        return abi.encode(from, to, amount, token);
    }
}
