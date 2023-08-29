// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IParam {
    /// @notice ExecutionDetails represents a series of logics to be executed
    struct ExecutionBatchDetails {
        bytes[] permit2Datas;
        LogicBatch logicBatch;
        address[] tokensReturn;
        uint256 referralCode;
        uint256 nonce;
        uint256 deadline;
    }

    /// @notice LogicBatch is signed by a signer using EIP-712
    struct LogicBatch {
        Logic[] logics; // An array of `Logic` structs to be executed
        Fee[] fees; // An array of `Fee` structs to be charged
        uint256 deadline; // The deadline for a signer's signature
    }

    /// @notice ExecutionDetails represents a series of logics to be executed
    struct ExecutionDetails {
        bytes[] permit2Datas;
        Logic[] logics;
        address[] tokensReturn;
        uint256 referralCode;
        uint256 nonce;
        uint256 deadline;
    }

    /// @notice Logic represents a single action to be executed
    struct Logic {
        address to; // The target address for the execution
        bytes data; // Encoded function calldata
        Input[] inputs; // An array of `Input` structs for amount calculation and token approval
        WrapMode wrapMode; // Determines if wrap or unwrap native
        address approveTo; // The address to approve tokens for if different from `to` such as a spender contract
        address callback; // The address allowed to make a one-time call to the agent
    }

    /// @notice Input represents a single input for token amount calculation and approval
    struct Input {
        address token; // Token address
        uint256 balanceBps; // Basis points for calculating the amount, set 0 to use amountOrOffset as amount
        uint256 amountOrOffset; // Read as amount if balanceBps is 0; otherwise, read as byte offset of amount in `Logic.data` for replacement, or set 1 << 255 for no replacement
    }

    /// @notice Fee represents a fee to be charged
    struct Fee {
        address token; // The token address
        uint256 amount; // The fee amount
        bytes32 metadata; // Metadata related to the fee
    }

    /// @notice WrapMode determines how to handle native during execution
    enum WrapMode {
        NONE, // No wrapping or unwrapping of native
        WRAP_BEFORE, // Wrap native before calling `Logic.to`
        UNWRAP_AFTER // Unwrap native after calling `Logic.to`
    }

    /// @notice Delegation details of a delegatee approval to execute on a user's behalf
    struct DelegationDetails {
        address delegatee;
        uint128 expiry;
        uint128 nonce;
        uint256 deadline;
    }

    /// @notice The delegation information to be saved in storage
    struct PackedDelegation {
        uint128 expiry;
        uint128 nonce;
    }
}
