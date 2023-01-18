// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISpenderERC20Approval {
    error InvalidRouter();
    error LengthMismatch();

    function pullToken(address token, uint256 amount) external;

    function pullTokens(address[] calldata tokens, uint256[] calldata amounts) external;

    function permitPullToken(address token, uint256 amount, uint256 nonce, uint256 deadline, bytes calldata signature) external;
}
