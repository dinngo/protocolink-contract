// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FeeBase} from './FeeBase.sol';
import {IFeeDecodeContract} from '../interfaces/IFeeDecodeContract.sol';

contract Permit2FeeDecode is IFeeDecodeContract, FeeBase {
    constructor(address router) FeeBase(router) {}

    function decodeData(bytes calldata data) external view returns (address, uint256, uint256) {
        (, , uint160 amount, address token) = abi.decode(data, (address, address, uint160, address));
        return (token, uint256(amount), feeRate);
    }

    function getUpdatedData(bytes calldata data) external view returns (bytes memory) {
        (address from, address to, uint160 amount, address token) = abi.decode(
            data,
            (address, address, uint160, address)
        );
        amount = uint160((amount * (BPS_BASE + feeRate)) / BPS_BASE);
        return abi.encode(from, to, amount, token);
    }
}
