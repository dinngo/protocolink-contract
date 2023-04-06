// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAgent} from './IAgent.sol';
import {IParam} from './IParam.sol';

interface IRouter {
    event SignerAdded(address indexed signer);

    event SignerRemoved(address indexed signer);

    event FeeCalculatorSet(bytes4 indexed selector, address indexed to, address indexed feeCalculator);

    event FeeCollectorSet(address indexed feeCollector_);

    event PauserSet(address indexed pauser);

    event Paused();

    event Resumed();

    event Execute(address indexed user, address indexed agent, uint256 indexed referral);

    event AgentCreated(address indexed agent, address indexed owner);

    error Reentrancy();

    error RouterIsPaused();

    error InvalidPauser();

    error LengthMismatch();

    error InvalidFeeCollector();

    error InvalidNewPauser();

    error SignatureExpired(uint256 deadline);

    error InvalidSigner(address signer);

    error InvalidSignature();

    error AgentAlreadyCreated();

    error FeeNotEnough(address token);

    function agentImplementation() external view returns (address);

    function agents(address owner) external view returns (IAgent);

    function signers(address signer) external view returns (bool);

    function feeCalculators(bytes4 selector, address to) external view returns (address);

    function user() external view returns (address);

    function feeCollector() external view returns (address);

    function pauser() external view returns (address);

    function paused() external view returns (bool);

    function owner() external view returns (address);

    function domainSeparator() external view returns (bytes32);

    function getAgent() external view returns (address);

    function getAgent(address user) external view returns (address);

    function getUserAgent() external view returns (address, address);

    function calcAgent(address user) external view returns (address);

    function getLogicsAndFees(
        IParam.Logic[] memory logics,
        uint256 msgValue
    ) external view returns (IParam.Logic[] memory, IParam.Fee[] memory, uint256);

    function getFeesByLogics(
        IParam.Logic[] memory logics,
        uint256 msgValue
    ) external view returns (IParam.Fee[] memory);

    function getLogicsDataWithFee(IParam.Logic[] memory logic) external view returns (IParam.Logic[] memory);

    function addSigner(address newSigner) external;

    function removeSigner(address signer) external;

    function setFeeCalculators(
        bytes4[] calldata selector,
        address[] calldata tos,
        address[] calldata feeCalculators_
    ) external;

    function setFeeCollector(address feeCollector_) external;

    function setPauser(address pauser_) external;

    function pause() external;

    function resume() external;

    function execute(
        IParam.Logic[] calldata logics,
        IParam.Fee[] calldata fees,
        address[] calldata tokensReturn,
        uint256 referral
    ) external payable;

    function executeWithSignature(
        IParam.LogicBatch calldata logicBatch,
        address signer,
        bytes calldata signature,
        address[] calldata tokensReturn,
        uint256 referral
    ) external payable;

    function newAgent() external returns (address payable);

    function newAgent(address user) external returns (address payable);
}
