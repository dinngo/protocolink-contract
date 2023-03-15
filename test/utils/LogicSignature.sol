// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IParam} from '../../src/interfaces/IParam.sol';

contract LogicSignature is Test {
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

    function getLogicBatchSignature(
        IParam.LogicBatch memory logicBatch,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal pure returns (bytes memory sig) {
        IParam.Logic[] memory logics = logicBatch.logics;
        bytes32[] memory logicHashes = new bytes32[](logics.length);
        for (uint256 i = 0; i < logics.length; ++i) {
            IParam.Input[] memory inputs = logics[i].inputs;
            bytes32[] memory inputHashes = new bytes32[](logics[i].inputs.length);
            for (uint256 j = 0; j < inputs.length; ++j) {
                inputHashes[j] = keccak256(abi.encode(_INPUT_TYPEHASH, inputs[j]));
            }

            logicHashes[i] = keccak256(
                abi.encode(
                    _LOGIC_TYPEHASH,
                    logics[i].to,
                    keccak256(logics[i].data),
                    keccak256(abi.encodePacked(inputHashes)),
                    logics[i].approveTo,
                    logics[i].callback
                )
            );
        }

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                '\x19\x01',
                domainSeparator,
                keccak256(
                    abi.encode(_LOGIC_BATCH_TYPEHASH, keccak256(abi.encodePacked(logicHashes)), logicBatch.deadline)
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }
}
