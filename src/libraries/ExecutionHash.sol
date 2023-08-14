// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IParam} from '../interfaces/IParam.sol';

/// @title Library for EIP-712 encode
/// @notice Contains typehash constants and hash functions for structs
library ExecutionHash {
    bytes32 internal constant _FEE_TYPEHASH = keccak256('Fee(address token,uint256 amount,bytes32 metadata)');
    bytes32 internal constant _INPUT_TYPEHASH =
        keccak256('Input(address token,uint256 balanceBps,uint256 amountOrOffset)');

    bytes32 internal constant _LOGIC_TYPEHASH =
        keccak256(
            'Logic(address to,bytes data,Input[] inputs,uint8 wrapMode,address approveTo,address callback)Input(address token,uint256 balanceBps,uint256 amountOrOffset)'
        );

    bytes32 internal constant _LOGIC_BATCH_TYPEHASH =
        keccak256(
            'LogicBatch(Logic[] logics,Fee[] fees,uint256 deadline)Fee(address token,uint256 amount,bytes32 metadata)Input(address token,uint256 balanceBps,uint256 amountOrOffset)Logic(address to,bytes data,Input[] inputs,uint8 wrapMode,address approveTo,address callback)'
        );

    bytes32 internal constant _EXECUTION_DETAILS_TYPEHASH =
        keccak256(
            'ExecutionDetails(Logic[] logics,address[] tokensReturn,uint256 referralCode,uint256 nonce,uint256 deadline)Input(address token,uint256 balanceBps,uint256 amountOrOffset)Logic(address to,bytes data,Input[] inputs,uint8 wrapMode,address approveTo,address callback)'
        );

    bytes32 internal constant _EXECUTION_BATCH_DETAILS_TYPEHASH =
        keccak256(
            'ExecutionBatchDetails(LogicBatch logicBatch,address[] tokensReturn,uint256 referralCode,uint256 nonce,uint256 deadline)Fee(address token,uint256 amount,bytes32 metadata)Input(address token,uint256 balanceBps,uint256 amountOrOffset)Logic(address to,bytes data,Input[] inputs,uint8 wrapMode,address approveTo,address callback)LogicBatch(Logic[] logics,Fee[] fees,uint256 deadline)'
        );

    function _hash(IParam.Fee calldata fee) internal pure returns (bytes32) {
        return keccak256(abi.encode(_FEE_TYPEHASH, fee));
    }

    function _hash(IParam.Input calldata input) internal pure returns (bytes32) {
        return keccak256(abi.encode(_INPUT_TYPEHASH, input));
    }

    function _hash(IParam.Logic calldata logic) internal pure returns (bytes32) {
        IParam.Input[] calldata inputs = logic.inputs;
        uint256 inputsLength = inputs.length;
        bytes32[] memory inputHashes = new bytes32[](inputsLength);

        for (uint256 i; i < inputsLength; ) {
            inputHashes[i] = _hash(inputs[i]);
            unchecked {
                ++i;
            }
        }

        return
            keccak256(
                abi.encode(
                    _LOGIC_TYPEHASH,
                    logic.to,
                    keccak256(logic.data),
                    keccak256(abi.encodePacked(inputHashes)),
                    logic.wrapMode,
                    logic.approveTo,
                    logic.callback
                )
            );
    }

    function _hash(IParam.LogicBatch calldata logicBatch) internal pure returns (bytes32) {
        IParam.Logic[] calldata logics = logicBatch.logics;
        IParam.Fee[] calldata fees = logicBatch.fees;
        uint256 logicsLength = logics.length;
        uint256 feesLength = fees.length;
        bytes32[] memory logicHashes = new bytes32[](logicsLength);
        bytes32[] memory feeHashes = new bytes32[](feesLength);

        for (uint256 i; i < logicsLength; ) {
            logicHashes[i] = _hash(logics[i]);
            unchecked {
                ++i;
            }
        }

        for (uint256 i; i < feesLength; ) {
            feeHashes[i] = _hash(fees[i]);
            unchecked {
                ++i;
            }
        }

        return
            keccak256(
                abi.encode(
                    _LOGIC_BATCH_TYPEHASH,
                    keccak256(abi.encodePacked(logicHashes)),
                    keccak256(abi.encodePacked(feeHashes)),
                    logicBatch.deadline
                )
            );
    }

    function _hash(IParam.ExecutionDetails calldata details) internal pure returns (bytes32) {
        IParam.Logic[] calldata logics = details.logics;
        uint256 logicsLength = logics.length;
        bytes32[] memory logicHashes = new bytes32[](logicsLength);

        for (uint256 i; i < logicsLength; ) {
            logicHashes[i] = _hash(logics[i]);
            unchecked {
                ++i;
            }
        }

        return
            keccak256(
                abi.encode(
                    _EXECUTION_DETAILS_TYPEHASH,
                    keccak256(abi.encodePacked(logicHashes)),
                    keccak256(abi.encode(details.tokensReturn)),
                    details.referralCode,
                    details.nonce,
                    details.deadline
                )
            );
    }

    function _hash(IParam.ExecutionBatchDetails calldata details) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _EXECUTION_BATCH_DETAILS_TYPEHASH,
                    details.logicBatch,
                    keccak256(abi.encode(details.tokensReturn)),
                    details.referralCode,
                    details.nonce,
                    details.deadline
                )
            );
    }
}
