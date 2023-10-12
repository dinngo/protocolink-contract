// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {DataType} from '../libraries/DataType.sol';

library Delegation {
    /// @notice Set the expiry and nonce of the delegatee.
    function updateAll(DataType.PackedDelegation storage delegated, uint128 expiry, uint128 nonce) internal {
        uint256 word;
        unchecked {
            word = _pack(expiry, nonce + 1);
        }
        assembly {
            sstore(delegated.slot, word)
        }
    }

    function _pack(uint128 expiry, uint128 nonce) private pure returns (uint256 word) {
        word = (uint256(nonce) << 128) | expiry;
    }
}
