// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

library CallbackLibrary {
    /// @dev Flag for identifying the initialized state and reducing gas cost when resetting `_callbackWithCharge`
    bytes32 internal constant INIT_CALLBACK_WITH_CHARGE = bytes32(bytes20(address(1)));

    /// @dev Flag for identifying whether to charge fee determined by the least significant bit of `_callbackWithCharge`
    bytes32 internal constant CHARGE_MASK = bytes32(uint256(1));

    function isCharging(bytes32 flag) internal pure returns (bool) {
        return (flag & CHARGE_MASK) != bytes32(0);
    }

    function isInitialized(bytes32 flag) internal pure returns (bool) {
        return flag != bytes32(0);
    }

    function isReset(bytes32 flag) internal pure returns (bool) {
        return flag == INIT_CALLBACK_WITH_CHARGE;
    }

    function isCallback(bytes32 flag, address caller) internal pure returns (bool) {
        return caller == address(bytes20(flag));
    }

    function getFlag(address callback, bool charge) internal pure returns (bytes32 flag) {
        if (charge) {
            flag = bytes32(bytes20(callback)) | CHARGE_MASK;
        } else {
            flag = bytes32(bytes20(callback));
        }
    }
}
