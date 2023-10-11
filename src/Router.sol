// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import {Ownable} from 'lib/openzeppelin-contracts/contracts/access/Ownable.sol';
import {SafeERC20, IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {EIP712} from 'lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol';
import {SignatureChecker} from 'lib/openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol';
import {IAgent, AgentImplementation} from './AgentImplementation.sol';
import {Agent} from './Agent.sol';
import {DataType} from './libraries/DataType.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {TypedDataHash} from './libraries/TypedDataHash.sol';
import {Delegation} from './libraries/Delegation.sol';

/// @title Entry point for Protocolink
contract Router is IRouter, Ownable, EIP712 {
    using SafeERC20 for IERC20;
    using TypedDataHash for DataType.LogicBatch;
    using TypedDataHash for DataType.ExecutionDetails;
    using TypedDataHash for DataType.ExecutionBatchDetails;
    using TypedDataHash for DataType.DelegationDetails;
    using Delegation for DataType.PackedDelegation;
    using SignatureChecker for address;

    /// @dev Flag for identifying the paused state used in `currentUser` for reducing cold read gas cost
    address internal constant _PAUSED = address(0);

    /// @dev Flag for identifying the initialized state and reducing gas cost when resetting `currentUser`
    address internal constant _INIT_CURRENT_USER = address(1);

    /// @dev Denominator for calculating basis points
    uint256 internal constant _BPS_BASE = 10_000;

    /// @notice Immutable implementation contract for all users' agents
    address public immutable agentImplementation;

    /// @notice Mapping for recording exclusive agent contract to each user
    mapping(address user => IAgent agent) public agents;

    /// @notice Mapping for user with each delegatee and expiry
    mapping(address user => mapping(address delegatee => DataType.PackedDelegation delegation)) public delegations;

    /// @notice Mapping for user with execution signature nonce
    mapping(address user => uint256 nonce) public executionNonces;

    /// @notice Mapping for recording valid signers
    mapping(address signer => bool valid) public signers;

    /// @notice Transient address for recording `msg.sender` which resets to `_INIT_CURRENT_USER` after each execution
    address public currentUser;

    /// @notice Address for receiving collected fees
    bytes32 public defaultReferral;

    /// @notice Address for invoking pause
    address public pauser;

    /// @notice Fee rate
    uint256 public feeRate;

    /// @dev Modifier for setting transient `currentUser` address and blocking reentrancy.
    modifier whenReady(address user) {
        if (currentUser != _INIT_CURRENT_USER) revert NotReady();
        currentUser = user;
        _;
        currentUser = _INIT_CURRENT_USER;
    }

    /// @dev Modifier for checking if a caller has the privilege to pause/unpause this contract
    modifier onlyPauser() {
        if (msg.sender != pauser) revert InvalidPauser();
        _;
    }

    /// @dev Create the router with EIP-712 and the agent implementation contracts
    constructor(address wrappedNative, address permit2, address deployer) EIP712('Protocolink', '1') {
        currentUser = _INIT_CURRENT_USER;
        agentImplementation = address(new AgentImplementation(wrappedNative, permit2));
        transferOwnership(deployer);
    }

    ///////////////////////////////////////////////////////////////////////////////////////
    /// Router related
    ///////////////////////////////////////////////////////////////////////////////////////

    /// @notice Pause `execute` and `executeWithSignerFee` by pauser
    function pause() external onlyPauser {
        if (currentUser == _PAUSED) revert AlreadyPaused();
        currentUser = _PAUSED;
        emit Paused();
    }

    /// @notice Unpause `execute` and `executeWithSignerFee` by pauser
    function unpause() external onlyPauser {
        if (currentUser != _PAUSED) revert NotPaused();
        currentUser = _INIT_CURRENT_USER;
        emit Unpaused();
    }

    /// @notice Rescue ERC-20 tokens in case of stuck tokens by owner
    /// @param token The token address
    /// @param receiver The receiver address
    /// @param amount The amount of tokens to be rescued
    function rescue(address token, address receiver, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(receiver, amount);
    }

    /// @notice Add a signer whose signature can pass the validation in `executeWithSignerFee` by owner
    /// @param signer The signer address to be added
    function addSigner(address signer) external onlyOwner {
        signers[signer] = true;
        emit SignerAdded(signer);
    }

    /// @notice Remove a signer by owner
    /// @param signer The signer address to be removed
    function removeSigner(address signer) external onlyOwner {
        delete signers[signer];
        emit SignerRemoved(signer);
    }

    /// @notice Set a new fee rate by owner
    /// @param feeRate_ The new fee rate in basis points
    function setFeeRate(uint256 feeRate_) external onlyOwner {
        if (feeRate_ >= _BPS_BASE) revert InvalidRate();
        feeRate = feeRate_;
        emit FeeRateSet(feeRate_);
    }

    /// @notice Set the fee collector address that collects fees from each user's agent by owner
    /// @param feeCollector_ The fee collector address
    function setFeeCollector(address feeCollector_) external onlyOwner {
        if (feeCollector_ == address(0)) revert InvalidFeeCollector();
        defaultReferral = bytes32(bytes20(feeCollector_)) | bytes32(_BPS_BASE);
        emit FeeCollectorSet(feeCollector_);
    }

    /// @notice Set the pauser address that can pause `execute` and `executeWithSignerFee` by owner
    /// @param pauser_ The pauser address
    function setPauser(address pauser_) external onlyOwner {
        if (pauser_ == address(0)) revert InvalidNewPauser();
        pauser = pauser_;
        emit PauserSet(pauser_);
    }

    /// @notice Get domain separator used for EIP-712
    /// @return The domain separator of Protocolink
    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /// @notice Get the fee collector address that collects fees from each user's agent
    /// @return The fee collector address
    function defaultCollector() external view returns (address) {
        return address(bytes20(defaultReferral));
    }

    /// @notice Get owner address
    /// @return The owner address
    function owner() public view override(IRouter, Ownable) returns (address) {
        return super.owner();
    }

    ///////////////////////////////////////////////////////////////////////////////////////
    /// Agent related
    ///////////////////////////////////////////////////////////////////////////////////////

    /// @notice Create an agent for `msg.sender`
    /// @return The newly created agent address
    function newAgent() external returns (address) {
        return newAgent(msg.sender);
    }

    /// @notice Create an agent for the user
    /// @param user The user address
    /// @return The newly created agent address
    function newAgent(address user) public returns (address) {
        if (address(agents[user]) != address(0)) {
            revert AgentAlreadyCreated();
        } else {
            return _newAgent(user);
        }
    }

    function _newAgent(address user) internal returns (address) {
        IAgent agent = IAgent(address(new Agent{salt: bytes32(bytes20(user))}(agentImplementation)));
        agents[user] = agent;
        emit AgentCreated(address(agent), user);
        return address(agent);
    }

    /// @notice Get agent address of a user
    /// @param user The user address
    /// @return The agent address of the user
    function getAgent(address user) external view returns (address) {
        return address(agents[user]);
    }

    /// @notice Get user and agent addresses of the current user
    /// @return The user address
    /// @return The agent address
    function getCurrentUserAgent() external view returns (address, address) {
        address user = currentUser;
        return (user, address(agents[user]));
    }

    /// @notice Calculate agent address for a user using the CREATE2 formula
    /// @param user The user address
    /// @return The calculated agent address for the user
    function calcAgent(address user) external view returns (address) {
        address result = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            bytes32(bytes20(user)),
                            keccak256(abi.encodePacked(type(Agent).creationCode, abi.encode(agentImplementation)))
                        )
                    )
                )
            )
        );
        return result;
    }

    ///////////////////////////////////////////////////////////////////////////////////////
    /// Execution related
    ///////////////////////////////////////////////////////////////////////////////////////

    /// @notice Execute arbitrary logics through the current user's agent. Creates an agent for user if not created.
    ///         Fees are charged in the user's agent during the execution of msg.value, permit2 and flash loans.
    /// @param permit2Datas Array of datas to be processed through permit2 contract
    /// @param logics Array of logics to be executed
    /// @param tokensReturn Array of ERC-20 tokens to be returned to the current user
    function execute(
        bytes[] calldata permit2Datas,
        DataType.Logic[] calldata logics,
        address[] calldata tokensReturn
    ) external payable whenReady(msg.sender) {
        _execute(msg.sender, permit2Datas, logics, tokensReturn);
    }

    /// @notice Execute arbitrary logics through the given user's agent after the delegation. Creates an agent for user if not created.
    ///         Fees are charged in the user's agent during the execution of msg.value, permit2 and flash loans.
    /// @param user The user address
    /// @param permit2Datas Array of datas to be processed through permit2 contract
    /// @param logics Array of logics to be executed
    /// @param tokensReturn Array of ERC-20 tokens to be returned to the current user
    function executeFor(
        address user,
        bytes[] calldata permit2Datas,
        DataType.Logic[] calldata logics,
        address[] calldata tokensReturn
    ) external payable whenReady(user) {
        if (!_isValidDelegateeFor(user)) revert InvalidDelegatee();
        _execute(user, permit2Datas, logics, tokensReturn);
    }

    /// @notice Execute permitted execution data through the given user's agent. Creates an agent for user if not created.
    ///         Fees are charged in the user's agent during the execution of msg.value, permit2 and flash loans.
    /// @param details The execution details permitted by user
    /// @param user The user address
    /// @param signature The user's signature bytes
    function executeBySig(
        DataType.ExecutionDetails calldata details,
        address user,
        bytes calldata signature
    ) external payable whenReady(user) {
        _validateExecutionDetails(details, user, signature);
        unchecked {
            ++executionNonces[user];
        }
        _execute(user, details.permit2Datas, details.logics, details.tokensReturn);
    }

    /// @notice Execute arbitrary logics through the current user's agent using a signer's signature. Creates an agent
    ///         for user if not created. Fees in logicBatch are off-chain encoded, rather than calculated in the user's
    ///         agent.
    /// @dev Allow whitelisted signers to use custom fee rules and permit the reuse of the signature until the deadline
    /// @param permit2Datas Array of datas to be processed through permit2 contract
    /// @param logicBatch A struct containing logics, fees and deadline, signed by a signer using EIP-712
    /// @param signer The signer address
    /// @param signature The signer's signature bytes
    /// @param tokensReturn Array of ERC-20 tokens to be returned to the current user
    function executeWithSignerFee(
        bytes[] calldata permit2Datas,
        DataType.LogicBatch calldata logicBatch,
        address signer,
        bytes calldata signature,
        address[] calldata tokensReturn
    ) external payable whenReady(msg.sender) {
        _validateLogicBatch(logicBatch, signer, signature);
        _executeWithSignerFee(msg.sender, permit2Datas, logicBatch, tokensReturn);
    }

    /// @notice Execute arbitrary logics through the given user's agent using a signer's signature. Creates an agent
    ///         for user if not created. Fees in logicBatch are off-chain encoded, rather than calculated in the user's
    ///         agent.
    /// @dev Allow whitelisted signers to use custom fee rules and permit the reuse of the signature until the deadline
    /// @param user The user address
    /// @param permit2Datas Array of datas to be processed through permit2 contract
    /// @param logicBatch A struct containing logics, fees and deadline, signed by a signer using EIP-712
    /// @param signer The signer address
    /// @param signature The signer's signature bytes
    /// @param tokensReturn Array of ERC-20 tokens to be returned to the current user
    function executeForWithSignerFee(
        address user,
        bytes[] calldata permit2Datas,
        DataType.LogicBatch calldata logicBatch,
        address signer,
        bytes calldata signature,
        address[] calldata tokensReturn
    ) external payable whenReady(user) {
        if (!_isValidDelegateeFor(user)) revert InvalidDelegatee();
        _validateLogicBatch(logicBatch, signer, signature);
        _executeWithSignerFee(user, permit2Datas, logicBatch, tokensReturn);
    }

    /// @notice Execute permitted execution data through the given user's agent using a signer's signature. Creates an agent
    ///         for user if not created. Fees in logicBatch are off-chain encoded, rather than calculated in the user's
    ///         agent.
    /// @param details The execution details permitted by user
    /// @param user The user address
    /// @param userSignature The user's signature bytes
    /// @param signer The signer address
    /// @param signerSignature The signer's signature bytes
    function executeBySigWithSignerFee(
        DataType.ExecutionBatchDetails calldata details,
        address user,
        bytes calldata userSignature,
        address signer,
        bytes calldata signerSignature
    ) external payable whenReady(user) {
        _validateExecutionBatchDetails(details, user, userSignature);
        DataType.LogicBatch calldata logicBatch = details.logicBatch;
        _validateLogicBatch(logicBatch, signer, signerSignature);
        unchecked {
            ++executionNonces[user];
        }
        _executeWithSignerFee(user, details.permit2Datas, logicBatch, details.tokensReturn);
    }

    function _execute(
        address user,
        bytes[] calldata permit2Datas,
        DataType.Logic[] calldata logics,
        address[] calldata tokensReturn
    ) internal {
        IAgent agent = agents[user];

        if (address(agent) == address(0)) {
            agent = IAgent(_newAgent(user));
        }

        emit Executed(user, address(agent));
        agent.execute{value: msg.value}(permit2Datas, logics, tokensReturn);
    }

    function _executeWithSignerFee(
        address user,
        bytes[] calldata permit2Datas,
        DataType.LogicBatch calldata logicBatch,
        address[] calldata tokensReturn
    ) internal {
        IAgent agent = agents[user];

        if (address(agent) == address(0)) {
            agent = IAgent(_newAgent(user));
        }

        emit Executed(user, address(agent));
        agent.executeWithSignerFee{value: msg.value}(
            permit2Datas,
            logicBatch.logics,
            logicBatch.fees,
            logicBatch.referrals,
            tokensReturn
        );
    }

    function _isValidDelegateeFor(address user) internal view returns (bool) {
        return block.timestamp <= uint256(delegations[user][msg.sender].expiry);
    }

    function _validateExecutionDetails(
        DataType.ExecutionDetails calldata details,
        address signer,
        bytes calldata signature
    ) internal view {
        uint256 deadline = details.deadline;
        if (block.timestamp > deadline) revert SignatureExpired(deadline);
        if (!signer.isValidSignatureNow(_hashTypedDataV4(details.hash()), signature)) revert InvalidSignature();
        if (executionNonces[signer] != details.nonce) revert InvalidNonce();
    }

    function _validateExecutionBatchDetails(
        DataType.ExecutionBatchDetails calldata details,
        address signer,
        bytes calldata signature
    ) internal view {
        uint256 deadline = details.deadline;
        if (block.timestamp > deadline) revert SignatureExpired(deadline);
        if (!signer.isValidSignatureNow(_hashTypedDataV4(details.hash()), signature)) revert InvalidSignature();
        if (executionNonces[signer] != details.nonce) revert InvalidNonce();
    }

    function _validateLogicBatch(
        DataType.LogicBatch calldata logicBatch,
        address signer,
        bytes calldata signature
    ) internal view {
        uint256 deadline = logicBatch.deadline;
        if (block.timestamp > deadline) revert SignatureExpired(deadline);
        if (!signers[signer]) revert InvalidSigner(signer);
        if (!signer.isValidSignatureNow(_hashTypedDataV4(logicBatch.hash()), signature)) revert InvalidSignature();
    }

    ///////////////////////////////////////////////////////////////////////////////////////
    /// Delegation management
    ///////////////////////////////////////////////////////////////////////////////////////

    /// @notice Allow another address to execute on user's behalf
    /// @param delegatee The address to be delegated
    /// @param expiry The expiry of the delegation
    function allow(address delegatee, uint128 expiry) public {
        delegations[msg.sender][delegatee].expiry = expiry;
        emit Delegated(msg.sender, delegatee, expiry);
    }

    /// @notice Set delegation information via signature
    /// @param details The delegation details to be signed by a delegator using EIP-712
    /// @param delegator The delegator address
    /// @param signature The delegator's signature bytes
    function allowBySig(
        DataType.DelegationDetails calldata details,
        address delegator,
        bytes calldata signature
    ) external {
        _validateDelegationDetails(details, delegator, signature);
        address delegatee = details.delegatee;
        uint128 expiry = details.expiry;
        delegations[delegator][delegatee].updateAll(expiry, details.nonce);
        emit Delegated(delegator, delegatee, expiry);
    }

    /// @notice Disallow another address to execute on user's behalf
    /// @param delegatee The address to be disallowed
    function disallow(address delegatee) external {
        allow(delegatee, 0);
    }

    function _validateDelegationDetails(
        DataType.DelegationDetails calldata details,
        address signer,
        bytes calldata signature
    ) internal view {
        uint256 deadline = details.deadline;
        uint128 nonce = details.nonce;
        if (block.timestamp > deadline) revert SignatureExpired(deadline);
        if (!signer.isValidSignatureNow(_hashTypedDataV4(details.hash()), signature)) revert InvalidSignature();
        if (delegations[signer][details.delegatee].nonce != nonce) revert InvalidNonce();
    }

    ///////////////////////////////////////////////////////////////////////////////////////
    /// Signature nonce management
    ///////////////////////////////////////////////////////////////////////////////////////

    /// @notice Invalidate nonces for a delegatee
    /// @param delegatee The delegatee to invalidate nonces for
    /// @param newNonce The new nonce to set. Invalidates all nonces less than it
    /// @dev Can't invalidate more than 2**16 nonces per transaction
    function invalidateDelegationNonces(address delegatee, uint128 newNonce) external {
        uint128 oldNonce = delegations[msg.sender][delegatee].nonce;
        if (newNonce <= oldNonce) revert InvalidNonce();
        // Limit the amount of nonces that can be invalidated in one transaction.
        unchecked {
            if (newNonce - oldNonce > type(uint16).max) revert ExcessiveInvalidation();
        }

        delegations[msg.sender][delegatee].nonce = newNonce;
        emit DelegationNonceInvalidation(msg.sender, delegatee, newNonce, oldNonce);
    }

    /// @notice Invalidate nonces for an execution
    /// @param newNonce The new nonce to set. Invalidates all nonces less than it
    /// @dev Can't invalidate more than 2**16 nonces per transaction
    function invalidateExecutionNonces(uint256 newNonce) external {
        uint256 oldNonce = executionNonces[msg.sender];
        if (newNonce <= oldNonce) revert InvalidNonce();
        // Limit the amount of nonces that can be invalidated in one transaction.
        unchecked {
            if (newNonce - oldNonce > type(uint16).max) revert ExcessiveInvalidation();
        }

        executionNonces[msg.sender] = newNonce;
        emit ExecutionNonceInvalidation(msg.sender, newNonce, oldNonce);
    }
}
