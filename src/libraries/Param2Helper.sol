// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IParam2} from '../interfaces/IParam2.sol';
import 'forge-std/console.sol';

library LogicHelper {
    bytes32 internal constant WRAP_MASK_ = 0x0000000000000000000000000000000000000000000000000000000000000001;
    bytes32 internal constant UNWRAP_MASK_ = 0x0000000000000000000000000000000000000000000000000000000000000002;

    function isWrapMode(IParam2.Logic calldata logic) internal pure returns (bool) {
        return ((WRAP_MASK_ & logic.metadata) > 0) && !((UNWRAP_MASK_ & logic.metadata) > 0);
    }

    function isUnWrapMode(IParam2.Logic calldata logic) internal pure returns (bool) {
        return ((UNWRAP_MASK_ & logic.metadata) > 0) && !((WRAP_MASK_ & logic.metadata) > 0);
    }

    function getApproveTo(IParam2.Logic calldata logic) internal pure returns (address) {
        return address(bytes20(logic.metadata));
    }
}

library InputHelper {
    uint256 internal constant _BPS_SKIP = 0;
    bytes32 internal constant REPLACE_MASK_ = 0x0000000000000000000000000000000000000000000000000000000000000001;
    bytes32 internal constant BPS_VALUE_MASK_ = 0x0000000000000000000000000000000000000000ffff00000000000000000000;

    function isReplaceCallData(IParam2.Input calldata input) internal pure returns (bool) {
        return ((REPLACE_MASK_ & input.tokenMetadata) > 0);
    }

    function getToken(IParam2.Input calldata input) internal pure returns (address) {
        return address(bytes20(input.tokenMetadata));
    }

    function getBps(IParam2.Input calldata input) internal pure returns (uint256) {
        return uint256((BPS_VALUE_MASK_ & input.tokenMetadata) >> 80);
    }

    function getTokenAndBps(
        IParam2.Input calldata input
    ) internal pure returns (address token, uint256 bps, bool bpsEnable) {
        token = address(bytes20(input.tokenMetadata));
        bps = uint256((BPS_VALUE_MASK_ & input.tokenMetadata) >> 80);
        bpsEnable = (bps != _BPS_SKIP);
    }
}
