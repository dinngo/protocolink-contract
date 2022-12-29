// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISpender {
    function pull(address token, uint256 amount) external;
}
