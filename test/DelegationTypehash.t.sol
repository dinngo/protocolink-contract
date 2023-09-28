// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SignatureChecker} from 'lib/openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {TypedDataSignature} from './utils/TypedDataSignature.sol';

contract DelegationTypehash is Test, TypedDataSignature {
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

    function testDelegationTypehash() external {
        // Sign a delegation using metamask to obtain an external sig
        // https://stackblitz.com/edit/github-n5du9g-zu5mon?file=index.tsx
        bytes32 r = 0x0a72526ee624f791e6ba9422605b948d6ef83269b3564f999bddec171c01fb90;
        bytes32 s = 0x3dbd916144c08cfff38009fe2b932db41ec31b6bffc1c6ebca772274b37f600e;
        uint8 v = 0x1c;
        bytes memory sig = bytes.concat(r, s, bytes1(v));

        // Create the delegation details with the same parameters as above
        DataType.DelegationDetails memory details = DataType.DelegationDetails(
            0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB,
            1704069200,
            0,
            1704067200
        );

        // Verify the locally generated signature using the private key is the same as the external sig
        assertEq(getTypedDataSignature(details, _buildDomainSeparator(), PRIVATE_KEY), sig);

        // Verify the signer can be recovered using the external sig
        bytes32 hashedTypedData = getHashedTypedData(details, _buildDomainSeparator());
        assertTrue(SIGNER.isValidSignatureNow(hashedTypedData, sig));
    }
}
