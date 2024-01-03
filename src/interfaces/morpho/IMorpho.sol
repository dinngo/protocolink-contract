// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IMorpho {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}
