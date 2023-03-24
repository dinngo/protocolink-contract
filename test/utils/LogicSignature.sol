// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {MockLogicHash} from '../mocks/MockLogicHash.sol';

contract LogicSignature is Test {
    MockLogicHash mockLogicHash;

    constructor() {
        mockLogicHash = new MockLogicHash();
    }

    function getLogicBatchHashedTypedData(
        IParam.LogicBatch memory logicBatch,
        bytes32 domainSeparator
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked('\x19\x01', domainSeparator, mockLogicHash.hash(logicBatch)));
    }

    function getLogicBatchSignature(
        IParam.LogicBatch memory logicBatch,
        bytes32 domainSeparator,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            getLogicBatchHashedTypedData(logicBatch, domainSeparator)
        );
        return bytes.concat(r, s, bytes1(v));
    }
}
