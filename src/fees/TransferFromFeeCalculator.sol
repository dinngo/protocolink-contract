// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FeeBase} from './FeeBase.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';
import {IParam} from '../interfaces/IParam.sol';

/// @notice Fee calculator for ERC20::transferFrom action. This will also cause ERC721::transferFrom being executed and fail in transaction.
contract TransferFromFeeCalculator is IFeeCalculator, FeeBase {
    bytes32 private constant _META_DATA = bytes32(bytes('erc20:transfer-from'));

    constructor(address router, uint256 feeRate) FeeBase(router, feeRate) {}

    function getFees(address to, bytes calldata data) external view returns (IParam.Fee[] memory) {
        // Token transfrom signature:'transferFrom(address,address,uint256)', selector:0x23b872dd
        (, , uint256 amount) = abi.decode(data[4:], (address, address, uint256));

        IParam.Fee[] memory fees = new IParam.Fee[](1);
        fees[0] = IParam.Fee({token: to, amount: calculateFee(amount), metadata: _META_DATA});
        return fees;
    }

    function getDataWithFee(bytes calldata data) external view returns (bytes memory) {
        (address from, address to, uint256 amount) = abi.decode(data[4:], (address, address, uint256));
        amount = calculateAmountWithFee(amount);
        return abi.encodePacked(data[:4], abi.encode(from, to, amount));
    }
}
