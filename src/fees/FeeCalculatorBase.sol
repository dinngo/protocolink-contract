// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IRouter} from '../interfaces/IRouter.sol';

/// @title Fee calculator base
/// @notice An abstract contract that provides basic functionality for calculating fees
abstract contract FeeCalculatorBase {
    error InvalidSender();
    error InvalidRate();

    /// @dev Denominator for calculating basis points
    uint256 internal constant _BPS_BASE = 10_000;

    /// @notice Immutable address for recording the router address
    address public immutable router;

    /// @notice Fee rate in basis points with 20 representing 0.2%
    uint256 public feeRate;

    /// @dev Initialize the router address and fee rate
    constructor(address router_, uint256 feeRate_) {
        router = router_;
        feeRate = feeRate_;
    }

    /// @notice Calculate the fee for the given amount
    /// @param amount The amount for which the fee needs to be calculated
    /// @return The calculated fee
    function calculateFee(uint256 amount) public view returns (uint256) {
        return (amount * feeRate) / (_BPS_BASE + feeRate);
    }

    /// @notice Calculate the fees for the given array of amounts
    /// @param amounts An array of amounts for which fees need to be calculated
    /// @return An array of calculated fees
    function calculateFee(uint256[] memory amounts) public view returns (uint256[] memory) {
        for (uint256 i = 0; i < amounts.length; ) {
            amounts[i] = (amounts[i] * feeRate) / (_BPS_BASE + feeRate);
            unchecked {
                ++i;
            }
        }
        return amounts;
    }

    /// @notice Calculate the amount with the fee included for the given amount
    /// @param amount The amount to calculate the total with the fee included
    /// @return The total amount with the fee included
    function calculateAmountWithFee(uint256 amount) public view returns (uint256) {
        return (amount * (_BPS_BASE + feeRate)) / _BPS_BASE;
    }

    /// @notice Calculate the amounts with the fees included for the given array of amounts
    /// @param amounts An array of amounts to calculate the totals with the fees included
    /// @return An array of the total amounts with the fees included
    function calculateAmountWithFee(uint256[] memory amounts) public view returns (uint256[] memory) {
        for (uint256 i = 0; i < amounts.length; ) {
            amounts[i] = (amounts[i] * (_BPS_BASE + feeRate)) / _BPS_BASE;
            unchecked {
                ++i;
            }
        }
        return amounts;
    }

    /// @notice Set a new fee rate by router owner
    /// @param feeRate_ The new fee rate in basis points
    function setFeeRate(uint256 feeRate_) external {
        if (msg.sender != IRouter(router).owner()) revert InvalidSender();
        if (feeRate_ >= _BPS_BASE) revert InvalidRate();
        feeRate = feeRate_;
    }
}
