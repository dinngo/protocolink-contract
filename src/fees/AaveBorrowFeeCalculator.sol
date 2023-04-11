// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {FeeBase} from './FeeBase.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';

contract AaveBorrowFeeCalculator is IFeeCalculator, FeeBase {
    constructor(address router, uint256 feeRate) FeeBase(router, feeRate) {}

    function getFees(bytes calldata data) external view returns (address[] memory, uint256[] memory) {
        // Aave borrow signature:'borrow(address,uint256,uint256,uint16,address)', selector:0xa415bcad
        (address token, uint256 amount, , , ) = abi.decode(data, (address, uint256, uint256, uint16, address));
        address[] memory tokens = new address[](1);
        tokens[0] = token;

        uint256[] memory fees = new uint256[](1);
        fees[0] = calculateFee(amount);
        return (tokens, fees);
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
