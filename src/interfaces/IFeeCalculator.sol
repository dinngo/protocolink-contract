// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IFeeCalculator {
    /// @notice Get fee tokens and fees by `data`
    function getFees(bytes calldata data) external view returns (address[] memory, uint256[] memory);

    /// @notice Return updated `data` that contains fee
    function getDataWithFee(bytes calldata data) external view returns (bytes memory);
}
