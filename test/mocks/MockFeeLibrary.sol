// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {DataType} from 'src/libraries/DataType.sol';
import {FeeLibrary} from 'src/libraries/FeeLibrary.sol';

contract MockFeeLibrary {
    using FeeLibrary for DataType.Fee;

    function pay(DataType.Fee memory fee, bytes32 referral) external {
        fee.pay(referral);
    }

    /// @dev Notice that fee should not be NATIVE and should be verified before calling
    function payFrom(DataType.Fee memory fee, address from, bytes32 referral, address permit2) external {
        fee.payFrom(from, referral, permit2);
    }
}
