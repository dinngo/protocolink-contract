// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IFeeGenerator {
    function getFeeCalculator(bytes4 selector, address to) external view returns (address feeCalculator);

    function getNativeFeeCalculator() external view returns (address nativeFeeCalculator);
}
