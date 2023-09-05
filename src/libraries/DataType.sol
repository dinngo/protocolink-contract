// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

library DataType {
    /// @notice The way to handle native during execution
    enum WrapMode {
        NONE, // No wrapping or unwrapping of native
        WRAP_BEFORE, // Wrap native before calling `Logic.to`
        UNWRAP_AFTER // Unwrap native after calling `Logic.to`
    }

    /// @notice A single input for token amount calculation and approval
    struct Input {
        address token; // Token address
        uint256 balanceBps; // Basis points for calculating the amount, set 0 to use amountOrOffset as amount
        uint256 amountOrOffset; // Read as amount if balanceBps is 0; otherwise, read as byte offset of amount in `Logic.data` for replacement, or set 1 << 255 for no replacement
    }

    /// @notice A single action to be executed
    struct Logic {
        address to; // The target address for the execution
        bytes data; // Encoded function calldata
        Input[] inputs; // An array of `Input` structs for amount calculation and token approval
        WrapMode wrapMode; // Determines if wrap or unwrap native
        address approveTo; // The address to approve tokens for if different from `to` such as a spender contract
        address callback; // The address allowed to make a one-time call to the agent
    }

    /// @notice A series of logics to be executed. This data is signed by user when performing a delegated execution by signature.
    struct ExecutionDetails {
        bytes[] permit2Datas; // An array of databytes to be executed on permit2
        Logic[] logics; // An array of `Logic` structs to be executed
        address[] tokensReturn; // An array of token addresses to be returned to user
        uint256 nonce; // The nonce of the data to be applied in the user signing process
        uint256 deadline; // The deadline of the signature
    }

    /// @notice The fee to be charged
    struct Fee {
        address token; // The token address
        uint256 amount; // The fee amount
        bytes32 metadata; // Metadata related to the fee
    }

    /// @notice A series of logics including fee. This data is signed by signer when applying signer fee.
    struct LogicBatch {
        Logic[] logics; // An array of `Logic` structs to be executed
        Fee[] fees; // An array of `Fee` structs to be charged
        bytes32[] referrals; // An array of referrals to be applied when charging fees
        uint256 deadline; // The deadline for a signer's signature
    }

    /// @notice A series of logics including fee to be executed. This data is signed by user when performing a delegated execution by signature.
    struct ExecutionBatchDetails {
        bytes[] permit2Datas; // An array of databytes to be executed on permit2
        LogicBatch logicBatch; // The `LogicBatch` data to be executed
        address[] tokensReturn; // An array of token addresses to be returned to user
        uint256 nonce; // The nonce of the data to be applied in the user signing process
        uint256 deadline; // The deadline of the signature
    }

    /// @notice Delegation details of a delegatee approval to execute on a user's behalf
    struct DelegationDetails {
        address delegatee; // The delegatee to be approved
        uint128 expiry; // The expiry of the approval
        uint128 nonce; // The nonce of the data to be applied in the user signing process
        uint256 deadline; // The deadline of the signature
    }

    /// @notice The delegation information to be saved in storage
    struct PackedDelegation {
        uint128 expiry; // The expiry of the approval
        uint128 nonce; // The nonce of the delegator
    }
}
