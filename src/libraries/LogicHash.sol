// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IParam} from '../interfaces/IParam.sol';

library LogicHash {
    bytes32 internal constant _INPUT_TYPEHASH =
        keccak256('Input(address token,uint256 amountBps,uint256 amountOrOffset)');

    bytes32 internal constant _LOGIC_TYPEHASH =
        keccak256(
            'Logic(address to,bytes data,Input[] inputs,address approveTo,address callback)Input(address token,uint256 amountBps,uint256 amountOrOffset)'
        );

    bytes32 internal constant _LOGIC_BATCH_TYPEHASH =
        keccak256(
            'LogicBatch(Logic[] logics,uint256 deadline)Logic(address to,bytes data,Input[] inputs,address approveTo,address callback)Input(address token,uint256 amountBps,uint256 amountOrOffset)'
        );

    function _hash(IParam.Input calldata input) internal pure returns (bytes32) {
        return keccak256(abi.encode(_INPUT_TYPEHASH, input));
    }

    function _hash(IParam.Logic calldata logic) internal pure returns (bytes32) {
        IParam.Input[] calldata inputs = logic.inputs;
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
                    logic.approveTo,
                    logic.callback
                )
            );
    }

    function _hash(IParam.LogicBatch calldata logicBatch) internal pure returns (bytes32) {
        IParam.Logic[] calldata logics = logicBatch.logics;
        uint256 logicsLength = logics.length;
        bytes32[] memory logicHashes = new bytes32[](logicsLength);

        for (uint256 i = 0; i < logicsLength; ) {
            logicHashes[i] = _hash(logics[i]);
            unchecked {
                ++i;
            }
        }

        return
            keccak256(abi.encode(_LOGIC_BATCH_TYPEHASH, keccak256(abi.encodePacked(logicHashes)), logicBatch.deadline));
    }
}
