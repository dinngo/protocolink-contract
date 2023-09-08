// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {DataType} from '../libraries/DataType.sol';

/// @title Library for EIP-712 encode
/// @notice Contains typehash constants and hash functions for structs
library TypedDataHash {
    bytes32 internal constant INPUT_TYPEHASH =
        keccak256('Input(address token,uint256 balanceBps,uint256 amountOrOffset)');

    bytes32 internal constant LOGIC_TYPEHASH =
        keccak256(
            'Logic(address to,bytes data,Input[] inputs,uint8 wrapMode,address approveTo,address callback)Input(address token,uint256 balanceBps,uint256 amountOrOffset)'
        );

    bytes32 internal constant EXECUTION_DETAILS_TYPEHASH =
        keccak256(
            'ExecutionDetails(bytes[] permit2Datas,Logic[] logics,address[] tokensReturn,uint256 nonce,uint256 deadline)Input(address token,uint256 balanceBps,uint256 amountOrOffset)Logic(address to,bytes data,Input[] inputs,uint8 wrapMode,address approveTo,address callback)'
        );

    bytes32 internal constant FEE_TYPEHASH = keccak256('Fee(address token,uint256 amount,bytes32 metadata)');

    bytes32 internal constant LOGIC_BATCH_TYPEHASH =
        keccak256(
            'LogicBatch(Logic[] logics,Fee[] fees,bytes32[] referrals,uint256 deadline)Fee(address token,uint256 amount,bytes32 metadata)Input(address token,uint256 balanceBps,uint256 amountOrOffset)Logic(address to,bytes data,Input[] inputs,uint8 wrapMode,address approveTo,address callback)'
        );

    bytes32 internal constant EXECUTION_BATCH_DETAILS_TYPEHASH =
        keccak256(
            'ExecutionBatchDetails(bytes[] permit2Datas,LogicBatch logicBatch,address[] tokensReturn,uint256 nonce,uint256 deadline)Fee(address token,uint256 amount,bytes32 metadata)Input(address token,uint256 balanceBps,uint256 amountOrOffset)Logic(address to,bytes data,Input[] inputs,uint8 wrapMode,address approveTo,address callback)LogicBatch(Logic[] logics,Fee[] fees,bytes32[] referrals,uint256 deadline)'
        );

    bytes32 internal constant DELEGATION_DETAILS_TYPEHASH =
        keccak256('DelegationDetails(address delegatee,uint128 expiry,uint128 nonce,uint256 deadline)');

    function hash(DataType.Input calldata input) internal pure returns (bytes32) {
        return keccak256(abi.encode(INPUT_TYPEHASH, input));
    }

    function hash(DataType.Logic calldata logic) internal pure returns (bytes32) {
        DataType.Input[] calldata inputs = logic.inputs;
        uint256 inputsLength = inputs.length;
        bytes32[] memory inputHashes = new bytes32[](inputsLength);

        for (uint256 i; i < inputsLength; ) {
            inputHashes[i] = hash(inputs[i]);
            unchecked {
                ++i;
            }
        }

        return
            keccak256(
                abi.encode(
                    LOGIC_TYPEHASH,
                    logic.to,
                    keccak256(logic.data),
                    keccak256(abi.encodePacked(inputHashes)),
                    logic.wrapMode,
                    logic.approveTo,
                    logic.callback
                )
            );
    }

    function hash(DataType.ExecutionDetails calldata details) internal pure returns (bytes32) {
        bytes[] calldata datas = details.permit2Datas;
        uint256 datasLength = datas.length;
        bytes32[] memory dataHashes = new bytes32[](datasLength);
        for (uint256 i; i < datasLength; ) {
            dataHashes[i] = keccak256(datas[i]);
            unchecked {
                ++i;
            }
        }

        DataType.Logic[] calldata logics = details.logics;
        uint256 logicsLength = logics.length;
        bytes32[] memory logicHashes = new bytes32[](logicsLength);
        for (uint256 i; i < logicsLength; ) {
            logicHashes[i] = hash(logics[i]);
            unchecked {
                ++i;
            }
        }

        return
            keccak256(
                abi.encode(
                    EXECUTION_DETAILS_TYPEHASH,
                    keccak256(abi.encodePacked(dataHashes)),
                    keccak256(abi.encodePacked(logicHashes)),
                    keccak256(abi.encodePacked(details.tokensReturn)),
                    details.nonce,
                    details.deadline
                )
            );
    }

    function hash(DataType.Fee calldata fee) internal pure returns (bytes32) {
        return keccak256(abi.encode(FEE_TYPEHASH, fee));
    }

    function hash(DataType.LogicBatch calldata logicBatch) internal pure returns (bytes32) {
        DataType.Logic[] calldata logics = logicBatch.logics;
        DataType.Fee[] calldata fees = logicBatch.fees;
        uint256 logicsLength = logics.length;
        uint256 feesLength = fees.length;
        bytes32[] memory logicHashes = new bytes32[](logicsLength);
        bytes32[] memory feeHashes = new bytes32[](feesLength);

        for (uint256 i; i < logicsLength; ) {
            logicHashes[i] = hash(logics[i]);
            unchecked {
                ++i;
            }
        }

        for (uint256 i; i < feesLength; ) {
            feeHashes[i] = hash(fees[i]);
            unchecked {
                ++i;
            }
        }

        return
            keccak256(
                abi.encode(
                    LOGIC_BATCH_TYPEHASH,
                    keccak256(abi.encodePacked(logicHashes)),
                    keccak256(abi.encodePacked(feeHashes)),
                    keccak256(abi.encodePacked(logicBatch.referrals)),
                    logicBatch.deadline
                )
            );
    }

    function hash(DataType.ExecutionBatchDetails calldata details) internal pure returns (bytes32) {
        bytes[] calldata datas = details.permit2Datas;
        uint256 datasLength = datas.length;
        bytes32[] memory dataHashes = new bytes32[](datasLength);
        for (uint256 i; i < datasLength; ) {
            dataHashes[i] = keccak256(datas[i]);
            unchecked {
                ++i;
            }
        }

        return
            keccak256(
                abi.encode(
                    EXECUTION_BATCH_DETAILS_TYPEHASH,
                    keccak256(abi.encodePacked(dataHashes)),
                    hash(details.logicBatch),
                    keccak256(abi.encodePacked(details.tokensReturn)),
                    details.nonce,
                    details.deadline
                )
            );
    }

    function hash(DataType.DelegationDetails calldata details) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    DELEGATION_DETAILS_TYPEHASH,
                    details.delegatee,
                    details.expiry,
                    details.nonce,
                    details.deadline
                )
            );
    }
}
