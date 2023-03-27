// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IParam {
    struct LogicBatch {
        Logic[] logics;
        uint256 deadline;
    }

    struct Logic {
        address to;
        bytes data;
        Input[] inputs;
        // Approve to another contract instead of `to` since some protocols use spender contract to pull tokens from user
        address approveTo;
        address callback;
    }

    struct Input {
        WrapMode wrapMode;
        address token;
        // 7_000 means the replacing amount is 70% of token balance. Set type(uint256).max to skip bps calculation so simply use amountOrOffset as amount
        uint256 amountBps;
        // If amountBps is skip, can simply read amountOrOffset as amount
        // If amountBps is not skip, amountOrOffset is byte offset of amount in Logic.data used for replacement. Set type(uint256).max to skip if don't need to replace.
        uint256 amountOrOffset;
    }

    enum WrapMode {
        NONE,
        WRAP_BEFORE,
        UNWRAP_AFTER
    }
}
