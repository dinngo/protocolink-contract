// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFeeDecodeContract {
    function decodeData(bytes calldata data) external pure returns (address, uint256);
}
