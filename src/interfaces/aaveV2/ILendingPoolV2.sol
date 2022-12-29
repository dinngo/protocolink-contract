// SPDX-License-Identifier: agpl-3.0

pragma solidity ^0.8.0;

interface ILendingPoolV2 {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)
        external;
}
