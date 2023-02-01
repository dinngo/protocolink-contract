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
        address callback;
    }

    struct Input {
        address token;
        uint256 amountBps; // 7_000 means the replacing amount is 70% of token balance. Set type(uint256).max to skip bps calculation so simply use amountFixed
        uint256 amountOffset; // The byte offset of amount in Logic.data used for replacing amount when amountBps is set. Set type(uint256).max to skip if amount is not in data.
        uint256 amountFixed; // The fixed amount of token. Only Works when amountBps is skip.
        bool doApprove;
    }

    struct Output {
        address token;
        uint256 amountMin;
    }

    function user() external view returns (address);

    function execute(Logic[] calldata logics, address[] calldata tokensReturn) external payable;
}
