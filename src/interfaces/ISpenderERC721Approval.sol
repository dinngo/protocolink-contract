// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISpenderERC721Approval {
    error InvalidAgent();
    error LengthMismatch();

    function pullToken(address token, uint256 tokenId) external;

    function pullTokens(address[] calldata tokens, uint256[] calldata tokenIds) external;
}
