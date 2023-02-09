// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISignatureTransfer} from './permit2/ISignatureTransfer.sol';
import {IAllowanceTransfer} from './permit2/IAllowanceTransfer.sol';

/// @dev Users must approve Permit2 before calling any of the transfer functions.
interface ISpenderPermit2ERC20 {
    error InvalidRouter();
    error InvalidSpender();
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

    /// @notice Permit a spender to a given amount of the user token via the user's EIP-712 signature
    /// @dev May fail if the owner's nonce was invalidated in-flight by invalidateNonce
    /// @param permitSingle Data signed over by the owner specifying the terms of approval
    /// @param signature The owner's signature over the permit data
    function permitToken(IAllowanceTransfer.PermitSingle memory permitSingle, bytes calldata signature) external;

    /// @notice Permit a spender to the signed amounts of the users tokens via the user's EIP-712 signature
    /// @dev May fail if the owner's nonce was invalidated in-flight by invalidateNonce
    /// @param permitBatch Data signed over by the owner specifying the terms of approval
    /// @param signature The owner's signature over the permit data
    function permitTokens(IAllowanceTransfer.PermitBatch memory permitBatch, bytes calldata signature) external;

    /// @notice Pull approved tokens from user to router
    /// @param token The token address to transfer
    /// @param amount The amount of the token to transfer
    function pullToken(address token, uint160 amount) external;

    /// @notice Pull approved tokens from user to router in a batch
    /// @dev Reverts if from is not user and to is not router address
    /// @param transferDetails Array of owners, recipients, amounts, and tokens for the transfers
    function pullTokens(IAllowanceTransfer.AllowanceTransferDetails[] calldata transferDetails) external;
}
