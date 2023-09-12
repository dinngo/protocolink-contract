// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IAgent} from './IAgent.sol';
import {DataType} from '../libraries/DataType.sol';

interface IRouter {
    event SignerAdded(address indexed signer);

    event SignerRemoved(address indexed signer);

    event Delegated(address indexed delegator, address indexed delegatee, uint128 expiry);

    event FeeCollectorSet(address indexed feeCollector_);

    event PauserSet(address indexed pauser);

    event Paused();

    event Unpaused();

    event Executed(address indexed user, address indexed agent);

    event AgentCreated(address indexed agent, address indexed user);

    event DelegationNonceInvalidation(
        address indexed user,
        address indexed delegatee,
        uint128 newNonce,
        uint128 oldNonce
    );

    event ExecutionNonceInvalidation(address indexed user, uint256 newNonce, uint256 oldNonce);

    event FeeRateSet(uint256 feeRate_);

    error NotReady();

    error InvalidPauser();

    error AlreadyPaused();

    error NotPaused();

    error InvalidFeeCollector();

    error InvalidNewPauser();

    error SignatureExpired(uint256 deadline);

    error InvalidSigner(address signer);

    error InvalidSignature();

    error InvalidDelegatee();

    error InvalidNonce();

    error InvalidRate();

    error AgentAlreadyCreated();

    error ExcessiveInvalidation();

    function agentImplementation() external view returns (address);

    function agents(address user) external view returns (IAgent);

    function delegations(address user, address delegatee) external view returns (uint128 expiry, uint128 nonce);

    function executionNonces(address user) external view returns (uint256 nonce);

    function signers(address signer) external view returns (bool);

    function currentUser() external view returns (address);

    function defaultReferral() external view returns (bytes32);

    function defaultCollector() external view returns (address);

    function pauser() external view returns (address);

    function owner() external view returns (address);

    function domainSeparator() external view returns (bytes32);

    function getAgent(address user) external view returns (address);

    function getCurrentUserAgent() external view returns (address, address);

    function feeRate() external view returns (uint256);

    function calcAgent(address user) external view returns (address);

    function addSigner(address signer) external;

    function removeSigner(address signer) external;

    function setFeeRate(uint256 feeRate_) external;

    function setFeeCollector(address feeCollector_) external;

    function setPauser(address pauser_) external;

    function rescue(address token, address receiver, uint256 amount) external;

    function pause() external;

    function unpause() external;

    function execute(
        bytes[] calldata permit2Datas,
        DataType.Logic[] calldata logics,
        address[] calldata tokensReturn
    ) external payable;

    function executeFor(
        address user,
        bytes[] calldata permit2Datas,
        DataType.Logic[] calldata logics,
        address[] calldata tokensReturn
    ) external payable;

    function executeBySig(
        DataType.ExecutionDetails calldata details,
        address user,
        bytes calldata signature
    ) external payable;

    function executeWithSignerFee(
        bytes[] calldata permit2Datas,
        DataType.LogicBatch calldata logicBatch,
        address signer,
        bytes calldata signature,
        address[] calldata tokensReturn
    ) external payable;

    function executeForWithSignerFee(
        address user,
        bytes[] calldata permit2Datas,
        DataType.LogicBatch calldata logicBatch,
        address signer,
        bytes calldata signature,
        address[] calldata tokensReturn
    ) external payable;

    function executeBySigWithSignerFee(
        DataType.ExecutionBatchDetails calldata details,
        address user,
        bytes calldata userSignature,
        address signer,
        bytes calldata signerSignature
    ) external payable;

    function invalidateExecutionNonces(uint256 newNonce) external;

    function newAgent() external returns (address);

    function newAgent(address user) external returns (address);

    function allow(address delegatee, uint128 expiry) external;

    function allowBySig(
        DataType.DelegationDetails calldata details,
        address delegator,
        bytes calldata signature
    ) external;

    function disallow(address delegatee) external;

    function invalidateDelegationNonces(address delegatee, uint128 newNonce) external;
}
