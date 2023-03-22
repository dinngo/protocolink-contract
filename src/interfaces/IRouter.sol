// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IParam} from './IParam.sol';

interface IRouter {
    event SignerAdded(address indexed signer, uint256 referral);

    event SignerRemoved(address indexed signer);

    event PauserSet(address indexed pauser);

    event Paused();

    event Resumed();

    error Reentrancy();

    error AgentCreated();

    error InvalidReferral(uint256 referral);

    error SignatureExpired(uint256 deadline);

    error InvalidSigner(address signer);

    error InvalidSignature();

    error InvalidPauser();

    error RouterIsPaused();

    error InvalidNewPauser();

    function agentImplementation() external view returns (address);

    function signerReferrals(address signer) external view returns (uint256);

    function user() external view returns (address);

    function pauser() external view returns (address);

    function paused() external view returns (bool);

    function domainSeparator() external view returns (bytes32);

    function getAgent() external view returns (address);

    function getAgent(address user) external view returns (address);

    function getUserAgent() external view returns (address, address);

    function calcAgent(address user) external view returns (address);

    function addSigner(address newSigner, uint256 referral) external;

    function removeSigner(address signer) external;

    function setPauser(address pauser_) external;

    function pause() external;

    function resume() external;

    function executeWithSignature(
        IParam.LogicBatch calldata logicBatch,
        address signer,
        bytes calldata signature,
        address[] calldata tokensReturn
    ) external payable;

    function execute(IParam.Logic[] calldata logics, address[] calldata tokensReturn) external payable;

    function newAgent() external returns (address payable);

    function newAgent(address user) external returns (address payable);
}
