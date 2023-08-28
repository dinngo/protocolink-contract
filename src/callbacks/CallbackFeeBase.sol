// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/// @title Base contract for calculating callback fees
abstract contract CallbackFeeBase {
    uint256 public immutable feeRate;
    bytes32 public immutable metadata;

    constructor(uint256 feeRate_, bytes32 metadata_) {
        feeRate = feeRate_;
        metadata = metadata_;
    }
}
