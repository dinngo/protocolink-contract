// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataType} from 'src/libraries/DataType.sol';
import {TypedDataHash} from 'src/libraries/TypedDataHash.sol';

contract MockTypedDataHash {
    using TypedDataHash for DataType.LogicBatch;
    using TypedDataHash for DataType.ExecutionDetails;
    using TypedDataHash for DataType.ExecutionBatchDetails;
    using TypedDataHash for DataType.DelegationDetails;

    function hash(DataType.LogicBatch calldata logicBatch) external pure returns (bytes32) {
        return logicBatch.hash();
    }

    function hash(DataType.ExecutionDetails calldata details) external pure returns (bytes32) {
        return details.hash();
    }

    function hash(DataType.ExecutionBatchDetails calldata details) external pure returns (bytes32) {
        return details.hash();
    }

    function hash(DataType.DelegationDetails calldata details) external pure returns (bytes32) {
        return details.hash();
    }
}
