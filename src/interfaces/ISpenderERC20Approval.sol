// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISpenderERC20Approval {
    function pull(address token, uint256 amount) external;
}
