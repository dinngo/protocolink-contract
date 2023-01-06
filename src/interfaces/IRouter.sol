// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRouter {
    error NotEmptyUser();

    error EmptyUser();

    error InvalidEntrant();

    error LengthMismatch();

    error InsufficientBalance(address tokenOut, uint256 amountOutMin, uint256 balance);

    struct Logic {
        address to;
        bytes data;
        Input[] inputs;
        // Output[] outputs;
        address entrant;
    }

    struct Input {
        address token;
        uint256 amountBps; // 7_000 means that the amount is 70% of the token balance
        uint256 amountOffset; // The byte offset of amount in Logic.data that will be replaced with the calculated token amount by bps
    }

    struct Output {
        address token;
        uint256 amountMin;
    }

    function user() external returns (address);

    function execute(address[] calldata tokensOut, uint256[] calldata amountsOutMin, Logic[] calldata logics)
        external;

    function executeUserSet(address[] calldata tokensOut, uint256[] calldata amountsOutMin, Logic[] calldata logics)
        external;
}
