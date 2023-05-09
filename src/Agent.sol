// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/// @title A user's agent contract created by the router
/// @notice A proxy for delegating calls to the immutable agent implementation contract
contract Agent {
    address internal immutable _implementation;

    /// @dev Create an initialized agent
    constructor(address implementation) {
        _implementation = implementation;
        (bool ok, ) = implementation.delegatecall(abi.encodeWithSignature('initialize()'));
        require(ok);
    }

    receive() external payable {}

    /// @notice Delegate all function calls to `_implementation`
    fallback() external payable {
        _delegate(_implementation);
    }

    /// @notice Delegate the call to `_implementation`
    /// @dev Referenced from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.1/contracts/proxy/Proxy.sol#L22
    /// @param implementation The address of the implementation contract that this agent delegates calls to
    function _delegate(address implementation) internal {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
