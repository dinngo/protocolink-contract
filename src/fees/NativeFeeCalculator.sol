// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FeeBase} from './FeeBase.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';

contract NativeFeeCalculator is IFeeCalculator, FeeBase {
    address private constant _NATIVE = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    constructor(address router, uint256 feeRate) FeeBase(router, feeRate) {}

    function getFee(bytes calldata data) external view returns (address, uint256) {
        return (_NATIVE, calculateFee(uint256(bytes32(data))));
    }

    function getDataWithFee(bytes calldata data) external pure returns (bytes memory) {
        return data;
    }
}
