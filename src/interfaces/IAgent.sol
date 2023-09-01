// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IParam} from './IParam.sol';

interface IAgent {
    event AmountReplaced(uint256 i, uint256 j, uint256 amount);

    event FeeCharged(address indexed token, uint256 amount, bytes32 metadata);

    error Initialized();

    error NotRouter();

    error NotCallback();

    error InvalidBps();

    error UnresetCallbackWithCharge();

    error InvalidPermit2Data(bytes4 selector);

    error InvalidPermitCall();

    function isCharging() external view returns (bool);

    function router() external returns (address);

    function wrappedNative() external returns (address);

    function permit2() external returns (address);

    function initialize() external;

    function execute(
        bytes[] calldata permit2Datas,
        IParam.Logic[] calldata logics,
        address[] calldata tokensReturn
    ) external payable;

    function executeWithSignerFee(
        bytes[] calldata permit2Datas,
        IParam.Logic[] calldata logics,
        IParam.Fee[] calldata fees,
        address[] calldata tokensReturn
    ) external payable;

    function executeByCallback(IParam.Logic[] calldata logics) external payable;
}
