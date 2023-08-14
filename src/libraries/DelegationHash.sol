// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IParam} from '../interfaces/IParam.sol';

/// @title Library for EIP-712 encode
/// @notice Contains typehash constants and hash functions for structs
library DelegationHash {
    bytes32 internal constant _DELEGATION_DETAILS_TYPEHASH =
        keccak256('DelegationDetails(address delegatee,uint128 expiry,uint128 nonce,uint256 deadline)');

    function _hash(IParam.DelegationDetails calldata details) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _DELEGATION_DETAILS_TYPEHASH,
                    details.delegatee,
                    details.expiry,
                    details.nonce,
                    details.deadline
                )
            );
    }
}
