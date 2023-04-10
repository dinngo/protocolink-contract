// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

interface IFeeCalculatorBase {
    function setFeeRate(uint256 feeRate_) external;
}

contract FeeCalculatorUtils is Test {
    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant ZERO_FEE_RATE = 0;

    function _calculateFee(uint256 amount, uint256 feeRate) internal pure returns (uint256) {
        return (amount * feeRate) / (BPS_BASE + feeRate);
    }

    function _calculateAmountWithFee(uint256 amount, uint256 feeRate) internal pure returns (uint256) {
        return (amount * (BPS_BASE + feeRate)) / BPS_BASE;
    }
}
