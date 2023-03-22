// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FeeBase} from './FeeBase.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';

contract AaveV2BorrowFeeCalculator is IFeeCalculator, FeeBase {
    constructor(address router, uint256 feeRate) FeeBase(router, feeRate) {}

    function getFee(bytes calldata data) external view returns (address, uint256) {
        // AaveV2 borrow signature:'borrow(address,uint256,uint256,uint16,address)', selector:0xa415bcad
        (address token, uint256 amount, , , ) = abi.decode(data, (address, uint256, uint256, uint256, address));
        return (token, calculateFee(uint256(amount)));
    }

    function getDataWithFee(bytes calldata data) external view returns (bytes memory) {
        (address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) = abi.decode(
            data,
            (address, uint256, uint256, uint16, address)
        );
        amount = calculateAmountWithFee(amount);
        return abi.encode(asset, amount, interestRateMode, referralCode, onBehalfOf);
    }
}
