// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRouter {
    error InvalidUser();

    error EmptyUser();

    error InvalidEntrant();

    error LengthMismatch();

    error InvalidERC20Sig();

    error UnresetEntrant();

    error InsufficientBalance(address tokenReturn, uint256 amountOutMin, uint256 balance);

    struct Logic {
        address to;
        bytes data;
        Input[] inputs;
        Output[] outputs;
        address entrant;
    }

    struct Input {
        address token;
        uint256 amountBps; // 7_000 means that the amount is 70% of the token balance
        uint256 amountOffset; // The byte offset of amount in Logic.data that will be replaced with the calculated token amount by bps
        bool doApprove;
    }

    struct Output {
        address token;
        uint256 amountMin;
    }

    function user() external view returns (address);

    function execute(Logic[] calldata logics, address[] calldata tokensReturn) external;

    function executeByEntrant(Logic[] calldata logics, address[] calldata tokensReturn) external;
}
