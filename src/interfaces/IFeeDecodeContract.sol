// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFeeDecodeContract {
    /// @notice Decode `data` to get fee charge token and fee
    /// @return Charge token, fee
    function decodeData(bytes calldata data) external view returns (address, uint256);

    /// @notice Return updated `data` that contains fee
    function getUpdatedData(bytes calldata data) external view returns (bytes memory);
}
