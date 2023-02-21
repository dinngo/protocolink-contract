// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IParam {
    struct Logic {
        address to;
        bytes data;
        Input[] inputs;
        Output[] outputs;
        address callback;
    }

    struct Input {
        address token;
        // 7_000 means the replacing amount is 70% of token balance. Set type(uint256).max to skip bps calculation so simply use amountOrOffset as amount
        uint256 amountBps;
        // If amountBps is skip, can simply read amountOrOffset as amount
        // If amountBps is not skip, amountOrOffset is byte offset of amount in Logic.data used for replacement. Set type(uint256).max to skip if don't need to replace.
        uint256 amountOrOffset;
    }

    struct Output {
        address token;
        uint256 amountMin;
    }
}
