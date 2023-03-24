// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRouter} from '../interfaces/IRouter.sol';

abstract contract FeeBase {
    error InvalidSender();
    error InvalidRate();

    uint256 private constant _BPS_BASE = 10_000;
    address public immutable router;

    uint256 public feeRate; // In bps, 20 means 0.2%

    constructor(address router_, uint256 feeRate_) {
        router = router_;
        feeRate = feeRate_;
    }

    function calculateFee(uint256 amount) public view returns (uint256) {
        return (amount * feeRate) / (_BPS_BASE + feeRate);
    }

    function calculateFee(uint256[] memory amounts) public view returns (uint256[] memory) {
        for (uint256 i = 0; i < amounts.length; ) {
            amounts[i] = (amounts[i] * feeRate) / (_BPS_BASE + feeRate);
            unchecked {
                ++i;
            }
        }
        return amounts;
    }

    function calculateAmountWithFee(uint256 amount) public view returns (uint256) {
        return (amount * (_BPS_BASE + feeRate)) / _BPS_BASE;
    }

    function calculateAmountWithFee(uint256[] memory amounts) public view returns (uint256[] memory) {
        for (uint256 i = 0; i < amounts.length; ) {
            amounts[i] = (amounts[i] * (_BPS_BASE + feeRate)) / _BPS_BASE;
            unchecked {
                ++i;
            }
        }
        return amounts;
    }

    function setFeeRate(uint256 feeRate_) external {
        if (msg.sender != IRouter(router).owner()) revert InvalidSender();
        if (feeRate >= _BPS_BASE) revert InvalidRate();
        feeRate = feeRate_;
    }
}
