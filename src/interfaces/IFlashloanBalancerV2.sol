// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashloanBalancerV2 {
    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
}
