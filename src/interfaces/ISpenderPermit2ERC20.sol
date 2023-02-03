// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISignatureTransfer} from './permit2/ISignatureTransfer.sol';
interface ISpenderPermit2ERC20 {
    error InvalidRouter();
    error LengthMismatch();
    error InvalidTransferTo();

    function permitPullToken(ISignatureTransfer.PermitTransferFrom memory permit, ISignatureTransfer.SignatureTransferDetails calldata transferDetails, bytes calldata signature) external;

    function permitPullTokens(ISignatureTransfer.PermitBatchTransferFrom memory permit, ISignatureTransfer.SignatureTransferDetails[] calldata transferDetails, bytes calldata signature) external;
}
