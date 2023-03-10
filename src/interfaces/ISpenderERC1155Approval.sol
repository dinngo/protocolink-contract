// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISpenderERC1155Approval {
    error InvalidAgent();
    error LengthMismatch();

    function pullToken(
        address token,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) external;

    function pullTokens(
        address[] calldata token,
        uint256[][] calldata tokenIds,
        uint256[][] calldata amounts
    ) external;
}
