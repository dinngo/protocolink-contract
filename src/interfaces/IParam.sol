// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IParam {
    struct Logic {
        address to;
        uint256 value; // amount of native token
        bytes data;
        Input[] inputs;
        address callback;
        bool chained; // flag for saving ret value
    }

    struct Input {
        uint256 index; // index of chained ret value
        uint256 valueOffset; // offset of the native token amount
        uint256 valueBps; // 7_000 means the replacing amount is 70% of token balance
        uint256[] retOffsets; // return data offsets
        uint256[] dataOffsets; // replaced data offsets
        uint256[] amountBps; // 7_000 means the replacing amount is 70% of token balance
    }
}
