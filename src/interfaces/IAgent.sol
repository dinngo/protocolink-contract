// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {DataType} from '../libraries/DataType.sol';

interface IAgent {
    event AmountReplaced(uint256 i, uint256 j, uint256 amount);

    event Charged(address indexed token, uint256 amount, address indexed collector, bytes32 metadata);

    error Initialized();

    error NotRouter();

    error NotCallback();

    error InvalidBps();

    error InvalidOffset();

    error UnresetCallbackWithCharge();

    error InvalidPermit2Data(bytes4 selector);

    function isCharging() external view returns (bool);

    function router() external returns (address);

    function wrappedNative() external returns (address);

    function permit2() external returns (address);

    function initialize() external;

    function execute(
        bytes[] calldata permit2Datas,
        DataType.Logic[] calldata logics,
        address[] calldata tokensReturn
    ) external payable;

    function executeWithSignerFee(
        bytes[] calldata permit2Datas,
        DataType.Logic[] calldata logics,
        DataType.Fee[] calldata fees,
        bytes32[] calldata referrals,
        address[] calldata tokensReturn
    ) external payable;

    function executeByCallback(DataType.Logic[] calldata logics) external payable;
}
