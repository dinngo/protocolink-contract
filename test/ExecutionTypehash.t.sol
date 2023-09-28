// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SignatureChecker} from 'lib/openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol';
import {IAllowanceTransfer} from 'lib/permit2/src/interfaces/IAllowanceTransfer.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {TypedDataSignature} from './utils/TypedDataSignature.sol';

contract ExecutionTypehash is Test, TypedDataSignature {
    using SignatureChecker for address;

    uint256 public constant PRIVATE_KEY = 0x290441b34d375a426eb23e32d27296fe944c734f58b21a1d2736191dfaafce90;
    address public constant SIGNER = 0x8C9dB529b394C8E1a9Fa34AE90F228202ca40712;

    uint256 public chainId;
    address public verifyingContract;

    function setUp() public {
        verifyingContract = 0x712BcCD6b7f8f5c3faE0418AC917f8929b371804;
        chainId = 1;
    }

    function _buildDomainSeparator() internal view returns (bytes32) {
        bytes32 typeHash = keccak256(
            'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
        );
        bytes32 nameHash = keccak256('Protocolink');
        bytes32 versionHash = keccak256('1');
        return keccak256(abi.encode(typeHash, nameHash, versionHash, chainId, verifyingContract));
    }

    function testExecutionTypehash() external {
        // Sign an execution using metamask to obtain an external sig
        // https://stackblitz.com/edit/github-n5du9g-n8cdi5?file=index.tsx
        bytes32 r = 0x9d7af15d25008b86af31294cb197594644a063b6ab5a003a5fa44c30cec9dfce;
        bytes32 s = 0x64337b3c36cda2928a07832a555679dfd5da27f7de20b320dfca14b05d5d039b;
        uint8 v = 0x1c;
        bytes memory sig = bytes.concat(r, s, bytes1(v));

        // Create the execution with the same parameters as above
        bytes[] memory permit2Datas = new bytes[](1);
        permit2Datas[0] = abi.encodeWithSelector(0x36c78516, SIGNER, verifyingContract, 1, address(2));
        DataType.Input[] memory inputs = new DataType.Input[](2);
        inputs[0] = DataType.Input(
            address(1), // token
            type(uint256).max, // balanceBps
            1 // amountOrOffset
        );
        inputs[1] = DataType.Input(
            address(2), // token
            10000, // balanceBps
            0x20 // amountOrOffset
        );
        DataType.Logic[] memory logics = new DataType.Logic[](2);
        logics[0] = DataType.Logic(
            address(3), // to
            '0123456789abcdef',
            inputs,
            DataType.WrapMode.WRAP_BEFORE,
            address(4), // approveTo
            address(5) // callback
        );
        logics[1] = logics[0]; // Duplicate logic
        address[] memory tokensReturn = new address[](2);
        tokensReturn[0] = address(6);
        tokensReturn[1] = address(7);
        uint256 nonce = 9;
        uint256 deadline = 1704067200;
        DataType.ExecutionDetails memory details = DataType.ExecutionDetails(
            permit2Datas,
            logics,
            tokensReturn,
            nonce,
            deadline
        );

        // Verify the locally generated signature using the private key is the same as the external sig
        assertEq(getTypedDataSignature(details, _buildDomainSeparator(), PRIVATE_KEY), sig);

        // Verify the signer can be recovered using the external sig
        bytes32 hashedTypedData = getHashedTypedData(details, _buildDomainSeparator());
        assertEq(SIGNER.isValidSignatureNow(hashedTypedData, sig), true);
    }

    function testExecutionBatchTypehash() external {
        // Sign an execution using metamask to obtain an external sig
        // https://stackblitz.com/edit/github-n5du9g-6cfxmy?file=index.tsx
        bytes32 r = 0x56c3c9b76519abeac06310197c7b71e377a0885e24302161b0e85d488c28cea7;
        bytes32 s = 0x0ac88a739c8a7f7f685fb63ee1d8c56e570e8625b89879891d61341a9718935a;
        uint8 v = 0x1c;
        bytes memory sig = bytes.concat(r, s, bytes1(v));

        // Create the execution with the same parameters as above
        bytes[] memory permit2Datas = new bytes[](1);
        permit2Datas[0] = abi.encodeWithSelector(0x36c78516, SIGNER, verifyingContract, 1, address(2));
        DataType.Input[] memory inputs = new DataType.Input[](2);
        inputs[0] = DataType.Input(
            address(1), // token
            type(uint256).max, // balanceBps
            1 // amountOrOffset
        );
        inputs[1] = DataType.Input(
            address(2), // token
            10000, // balanceBps
            0x20 // amountOrOffset
        );
        DataType.Logic[] memory logics = new DataType.Logic[](2);
        logics[0] = DataType.Logic(
            address(3), // to
            '0123456789abcdef',
            inputs,
            DataType.WrapMode.WRAP_BEFORE,
            address(4), // approveTo
            address(5) // callback
        );
        logics[1] = logics[0]; // Duplicate logic
        DataType.Fee[] memory fees = new DataType.Fee[](2);
        fees[0] = DataType.Fee(address(6), 1, bytes32(abi.encodePacked('metadata')));
        fees[1] = fees[0]; // Duplicate fee
        bytes32[] memory referrals = new bytes32[](1);
        referrals[0] = bytes32(uint256(8));
        uint256 deadline = 1704067200;
        DataType.LogicBatch memory logicBatch = DataType.LogicBatch(logics, fees, referrals, deadline);
        address[] memory tokensReturn = new address[](2);
        tokensReturn[0] = address(6);
        tokensReturn[1] = address(7);
        uint256 nonce = 9;
        DataType.ExecutionBatchDetails memory details = DataType.ExecutionBatchDetails(
            permit2Datas,
            logicBatch,
            tokensReturn,
            nonce,
            deadline
        );

        // Verify the locally generated signature using the private key is the same as the external sig
        assertEq(getTypedDataSignature(details, _buildDomainSeparator(), PRIVATE_KEY), sig);

        // Verify the signer can be recovered using the external sig
        bytes32 hashedTypedData = getHashedTypedData(details, _buildDomainSeparator());
        assertTrue(SIGNER.isValidSignatureNow(hashedTypedData, sig));
    }
}
