// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFeeDecodeContract} from '../interfaces/IFeeDecodeContract.sol';

contract Permit2FeeDecode is IFeeDecodeContract {
    function decodeData(bytes calldata data) external pure returns (address, uint256) {
        (, , uint160 amount, address token) = abi.decode(data, (address, address, uint160, address));
        return (token, uint256(amount));
    }
}
