// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SignatureChecker} from 'lib/openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {TypedDataSignature} from './utils/TypedDataSignature.sol';

contract LogicTypehash is Test, TypedDataSignature {
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

    function testLogicBatchTypehash() external {
        // Signed a logicBatch using metamask to obtain an external sig
        // https://stackblitz.com/edit/github-n5du9g-vs99sw?file=index.tsx
        bytes32 r = 0x17596488ceb1bc0451bd9484dcb56783e4ef7007324c933a664b1f4f3a080ac7;
        bytes32 s = 0x45b94050499753507fb2efe92ad0a2df0378b2c03bd50e65a350968d51c40884;
        uint8 v = 0x1c;
        bytes memory sig = bytes.concat(r, s, bytes1(v));

        // Create the logicBatch with the same parameters as above
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

        // Verify the locally generated signature using the private key is the same as the external sig
        assertEq(getTypedDataSignature(logicBatch, _buildDomainSeparator(), PRIVATE_KEY), sig);

        // Verify the signer can be recovered using the external sig
        bytes32 hashedTypedData = getHashedTypedData(logicBatch, _buildDomainSeparator());
        assertTrue(SIGNER.isValidSignatureNow(hashedTypedData, sig));
    }
}
