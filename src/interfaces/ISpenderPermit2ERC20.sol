// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISignatureTransfer} from './permit2/ISignatureTransfer.sol';
import {IAllowanceTransfer} from './permit2/IAllowanceTransfer.sol';

/// @dev Users must approve Permit2 before calling any of the transfer functions.
interface ISpenderPermit2ERC20 {
    error InvalidAgent();
    error InvalidTransferFrom();
    error InvalidTransferTo();

    ///=================================================================
    /// ISignatureTransfer way
    /// Attach a signature to each transaction,
    /// which can achieve token permit and omit the approve transaction
    ///=================================================================

    /// @notice Pull a token from user to router using a signed permit message
    /// @dev Reverts if the requested amount is greater than the permitted signed amount
    /// @param permit The permit data signed over by the owner
    /// @param transferDetails The spender's requested transfer details for the permitted token
    /// @param signature The signature to verify
    function permitPullToken(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        bytes calldata signature
    ) external;

    /// @notice Pull multiple tokens from user to router using a signed permit message
    /// @param permit The permit data signed over by the owner
    /// @param transferDetails Specifies the recipient and requested amount for the token transfer
    /// @param signature The signature to verify
    function permitPullTokens(
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails[] calldata transferDetails,
        bytes calldata signature
    ) external;

    ///=================================================================
    /// IAllowanceTransfer way
    /// The user can permit the token to a third party with an allowance for an additional period,
    /// which can then be used directly.
    ///=================================================================

    /// @notice Pull approved tokens from user to router
    /// @param token The token address to transfer
    /// @param amount The amount of the token to transfer
    function pullToken(address token, uint160 amount) external;

    /// @notice Pull approved tokens from user to router in a batch
    /// @dev Reverts if from is not user and to is not router address
    /// @param transferDetails Array of owners, recipients, amounts, and tokens for the transfers
    function pullTokens(IAllowanceTransfer.AllowanceTransferDetails[] calldata transferDetails) external;
}
