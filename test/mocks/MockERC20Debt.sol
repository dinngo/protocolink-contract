// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from 'openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';

contract MockERC20Debt is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    mapping(address => mapping(address => uint256)) internal _borrowAllowances;

    function approveDelegation(address delegatee, uint256 amount) public {
        _borrowAllowances[msg.sender][delegatee] = amount;
    }

    function borrowAllowance(address fromUser, address toUser) external view returns (uint256) {
        return _borrowAllowances[fromUser][toUser];
    }
}
