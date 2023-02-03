// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISignatureTransfer} from './permit2/ISignatureTransfer.sol';
import {IAllowanceTransfer} from './permit2/IAllowanceTransfer.sol';

interface ISpenderPermit2ERC20 {
    error InvalidRouter();
    error LengthMismatch();
    error InvalidTransferTo();
    error InvalidSpender();

    // ISignatureTransfer
    function permitPullToken(ISignatureTransfer.PermitTransferFrom memory permit, ISignatureTransfer.SignatureTransferDetails calldata transferDetails, bytes calldata signature) external;

    function permitPullTokens(ISignatureTransfer.PermitBatchTransferFrom memory permit, ISignatureTransfer.SignatureTransferDetails[] calldata transferDetails, bytes calldata signature) external;

    // IAllowanceTransfer
    function permitToken(IAllowanceTransfer.PermitSingle memory permitSingle, bytes calldata signature) external;

    function permitTokens(IAllowanceTransfer.PermitBatch memory PermitBatch, bytes calldata signature) external;

    function pullToken(address token, uint256 amount) external;

    function pullTokens(address[] calldata tokens, uint256[] calldata amounts) external;
}
