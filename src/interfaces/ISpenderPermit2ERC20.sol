// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISpenderPermit2ERC20 {
    error InvalidRouter();
    error LengthMismatch();

    function permitPullToken(address token, uint256 amount, uint256 nonce, uint256 deadline, bytes calldata signature) external;

    function permitPullTokens(address[] calldata tokens, uint256[] calldata amounts, uint256 nonce, uint256 deadline, bytes calldata signature) external;
}
