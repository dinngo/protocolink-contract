// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {MockTypedDataHash} from '../mocks/MockTypedDataHash.sol';

contract TypedDataSignature is Test {
    MockTypedDataHash mockTypedDataHash;

    constructor() {
        mockTypedDataHash = new MockTypedDataHash();
    }

    function getHashedTypedData(
        IParam.LogicBatch memory logicBatch,
        bytes32 domainSeparator
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked('\x19\x01', domainSeparator, mockTypedDataHash.hash(logicBatch)));
    }

    function getHashedTypedData(
        IParam.ExecutionDetails memory details,
        bytes32 domainSeparator
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked('\x19\x01', domainSeparator, mockTypedDataHash.hash(details)));
    }

    function getHashedTypedData(
        IParam.ExecutionBatchDetails memory details,
        bytes32 domainSeparator
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked('\x19\x01', domainSeparator, mockTypedDataHash.hash(details)));
    }

    function getHashedTypedData(
        IParam.DelegationDetails memory details,
        bytes32 domainSeparator
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked('\x19\x01', domainSeparator, mockTypedDataHash.hash(details)));
    }

    function getTypedDataSignature(
        IParam.LogicBatch memory logicBatch,
        bytes32 domainSeparator,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, getHashedTypedData(logicBatch, domainSeparator));
        return bytes.concat(r, s, bytes1(v));
    }

    function getTypedDataSignature(
        IParam.ExecutionDetails memory details,
        bytes32 domainSeparator,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, getHashedTypedData(details, domainSeparator));
        return bytes.concat(r, s, bytes1(v));
    }

    function getTypedDataSignature(
        IParam.ExecutionBatchDetails memory details,
        bytes32 domainSeparator,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, getHashedTypedData(details, domainSeparator));
        return bytes.concat(r, s, bytes1(v));
    }

    function getTypedDataSignature(
        IParam.DelegationDetails memory details,
        bytes32 domainSeparator,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, getHashedTypedData(details, domainSeparator));
        return bytes.concat(r, s, bytes1(v));
    }
}
