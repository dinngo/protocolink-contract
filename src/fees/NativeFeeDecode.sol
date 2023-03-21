// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FeeBase} from './FeeBase.sol';
import {IFeeDecodeContract} from '../interfaces/IFeeDecodeContract.sol';

contract NativeFeeDecode is IFeeDecodeContract, FeeBase {
    address private constant _NATIVE = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    constructor(address router) FeeBase(router) {}

    function decodeData(bytes calldata data) external view returns (address, uint256) {
        return (_NATIVE, calculateFee(uint256(bytes32(data))));
    }

    function getUpdatedData(bytes calldata data) external pure returns (bytes memory) {
        return data;
    }
}
