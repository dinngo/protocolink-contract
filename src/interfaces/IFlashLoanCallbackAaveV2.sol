// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoanCallbackAaveV2 {
    error InvalidCaller();

    error InvalidBalance(address asset);

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}
