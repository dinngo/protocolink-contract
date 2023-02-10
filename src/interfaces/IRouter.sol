// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRouter {
    error InvalidCallback();

    error LengthMismatch();

    error InvalidERC20Sig();

    error InvalidBps();

    error UnresetCallback();

    error InsufficientBalance(address tokenReturn, uint256 amountOutMin, uint256 balance);

    struct Logic {
        address to;
        bytes data;
        Input[] inputs;
        Output[] outputs;
        // Approve to another contract instead of `to` since some protocols use spender contract to pull tokens from user
        address approveTo;
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

    function user() external view returns (address);

    function execute(Logic[] calldata logics, address[] calldata tokensReturn) external payable;
}
