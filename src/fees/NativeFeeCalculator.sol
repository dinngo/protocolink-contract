// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FeeBase} from './FeeBase.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';
import {IParam} from '../interfaces/IParam.sol';

contract NativeFeeCalculator is IFeeCalculator, FeeBase {
    bytes32 private constant _META_DATA = bytes32(bytes('native-token'));
    address private constant _NATIVE = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    constructor(address router, uint256 feeRate) FeeBase(router, feeRate) {}

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
