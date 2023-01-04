// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IBalancerV2Vault {
    function flashLoan(address receiver, address[] calldata tokens, uint256[] calldata amounts, bytes calldata userData)
        external;
}
