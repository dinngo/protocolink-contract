// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWrappedNative {
    function deposit() external payable;

    function withdraw(uint256 amount) external;
}
