// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRouter} from '../interfaces/IRouter.sol';

abstract contract FeeBase {
    uint256 public constant BPS_BASE = 10_000;
    address public immutable router;

    uint256 public feeRate = 20; // Default 0.2% fee rate

    constructor(address router_) {
        router = router_;
    }

    function setFeeRate(uint256 feeRate_) public {
        require(msg.sender == IRouter(router).owner(), 'Invalid sender');
        require(feeRate_ < BPS_BASE, 'Invalid rate');
        feeRate = feeRate_;
    }

    function calculateFee(uint256 amount) public view returns (uint256) {
        return (amount * feeRate) / (BPS_BASE + feeRate);
    }
}
