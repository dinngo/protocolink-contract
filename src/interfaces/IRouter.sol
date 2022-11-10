// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRouter {
    struct Logic {
        address to;
        address[] tokensIn;
        uint256[] amountsInOffset; // Byte offset in data
        bytes data;
    }

    function execute(
        uint256[] calldata amountsIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsOutMin,
        Logic[] calldata logics
    ) external;
}
