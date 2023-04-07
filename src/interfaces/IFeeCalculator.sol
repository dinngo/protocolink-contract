// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFeeCalculator {
    /// @notice Get fee tokens, fees and metadata by `data`
    function getFees(
        address callee,
        bytes calldata data
    ) external view returns (address[] memory, uint256[] memory, bytes32);

    /// @notice Return updated `data` that contains fee
    function getDataWithFee(bytes calldata data) external view returns (bytes memory);
}
