// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IParam} from 'src/interfaces/IParam.sol';
import {TypedDataHash} from 'src/libraries/TypedDataHash.sol';

contract MockTypedDataHash {
    using TypedDataHash for IParam.LogicBatch;
    using TypedDataHash for IParam.ExecutionDetails;
    using TypedDataHash for IParam.ExecutionBatchDetails;
    using TypedDataHash for IParam.DelegationDetails;

    function hash(IParam.LogicBatch calldata logicBatch) external pure returns (bytes32) {
        return logicBatch._hash();
    }

    function hash(IParam.ExecutionDetails calldata details) external pure returns (bytes32) {
        return details._hash();
    }

    function hash(IParam.ExecutionBatchDetails calldata details) external pure returns (bytes32) {
        return details._hash();
    }

    function hash(IParam.DelegationDetails calldata details) external pure returns (bytes32) {
        return details._hash();
    }
}
