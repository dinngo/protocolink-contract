// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IParam2} from '../interfaces/IParam2.sol';

/// @title Library for EIP-712 encode
/// @notice Contains typehash constants and hash functions for structs
library LogicHash2 {
    bytes32 internal constant _FEE_TYPEHASH = keccak256('Fee(address token,uint256 amount,bytes32 metadata)');
    bytes32 internal constant _INPUT_TYPEHASH =
        keccak256('Input(address token,uint256 amountBps,uint256 amountOrOffset)');

    bytes32 internal constant _LOGIC_TYPEHASH =
        keccak256(
            'Logic(address to,bytes data,Input[] inputs,uint8 wrapMode,address approveTo,address callback)Input(address token,uint256 amountBps,uint256 amountOrOffset)'
        );

    bytes32 internal constant _LOGIC_BATCH_TYPEHASH =
        keccak256(
            'LogicBatch(Logic[] logics,Fee[] fees,uint256 deadline)Fee(address token,uint256 amount,bytes32 metadata)Input(address token,uint256 amountBps,uint256 amountOrOffset)Logic(address to,bytes data,Input[] inputs,uint8 wrapMode,address approveTo,address callback)'
        );

    function _hash(IParam2.Fee calldata fee) internal pure returns (bytes32) {
        return keccak256(abi.encode(_FEE_TYPEHASH, fee));
    }

    function _hash(IParam2.Input calldata input) internal pure returns (bytes32) {
        return keccak256(abi.encode(_INPUT_TYPEHASH, input));
    }

    function _hash(IParam2.Logic calldata logic) internal pure returns (bytes32) {
        IParam2.Input[] calldata inputs = logic.inputs;
        uint256 inputsLength = inputs.length;
        bytes32[] memory inputHashes = new bytes32[](inputsLength);

        for (uint256 i = 0; i < inputsLength; ) {
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
                    logic.metadata,
                    logic.callback
                )
            );
    }

    function _hash(IParam2.LogicBatch calldata logicBatch) internal pure returns (bytes32) {
        IParam2.Logic[] calldata logics = logicBatch.logics;
        IParam2.Fee[] calldata fees = logicBatch.fees;
        uint256 logicsLength = logics.length;
        uint256 feesLength = fees.length;
        bytes32[] memory logicHashes = new bytes32[](logicsLength);
        bytes32[] memory feeHashes = new bytes32[](feesLength);

        for (uint256 i = 0; i < logicsLength; ) {
            logicHashes[i] = _hash(logics[i]);
            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < feesLength; ) {
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
}
