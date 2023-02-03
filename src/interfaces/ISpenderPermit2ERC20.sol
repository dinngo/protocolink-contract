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
    error LengthMismatch();

    // ISignatureTransfer
    function permitPullToken(ISignatureTransfer.PermitTransferFrom memory permit, ISignatureTransfer.SignatureTransferDetails calldata transferDetails, bytes calldata signature) external;

    function permitPullTokens(ISignatureTransfer.PermitBatchTransferFrom memory permit, ISignatureTransfer.SignatureTransferDetails[] calldata transferDetails, bytes calldata signature) external;

    // IAllowanceTransfer
    function permitToken(IAllowanceTransfer.PermitSingle memory permitSingle, bytes calldata signature) external;

    function permitTokens(IAllowanceTransfer.PermitBatch memory PermitBatch, bytes calldata signature) external;

    function pullToken(address token, uint160 amount) external;

    function pullTokens(IAllowanceTransfer.AllowanceTransferDetails[] calldata transferDetails) external;
}
