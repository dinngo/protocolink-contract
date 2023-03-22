// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFeeCalculator {
    /// @notice Get fee token and fee by `data`
    function getFee(bytes calldata data) external view returns (address, uint256);

    /// @notice Return updated `data` that contains fee
    function getDataWithFee(bytes calldata data) external view returns (bytes memory);
}
