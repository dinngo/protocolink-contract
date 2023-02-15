// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoanCallbackBalancerV2 {
    error InvalidCaller();

    error InvalidBalance(address token);

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
}
