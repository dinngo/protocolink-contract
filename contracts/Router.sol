// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import {SafeERC20, IERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {EIP712} from '@openzeppelin/contracts/utils/cryptography/EIP712.sol';
import {SignatureChecker} from '@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol';
import {IAgent, AgentImplementation} from './AgentImplementation.sol';
import {Agent} from './Agent.sol';
import {FeeGenerator} from './fees/FeeGenerator.sol';
import {IParam} from './interfaces/IParam.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {LogicHash} from './libraries/LogicHash.sol';

/// @title Entry point for Protocolink
contract Router is IRouter, EIP712, FeeGenerator {
    using SafeERC20 for IERC20;
    using LogicHash for IParam.LogicBatch;
    using SignatureChecker for address;

    /// @dev Flag for identifying the paused state used in `currentUser` for reducing cold read gas cost
    address internal constant _PAUSED = address(0);

    /// @dev Flag for identifying the initialized state and reducing gas cost when resetting `currentUser`
    address internal constant _INIT_CURRENT_USER = address(1);

    /// @notice Immutable implementation contract for all users' agents
    address public immutable agentImplementation;
    bytes32 public immutable agentBytecodeHash;
    bytes32 public immutable constructorInputHash;

    /// @notice Mapping for recording exclusive agent contract to each user
    mapping(address user => IAgent agent) public agents;

    /// @notice Mapping for recording valid signers
    mapping(address signer => bool valid) public signers;

    /// @notice Transient address for recording `msg.sender` which resets to `_INIT_CURRENT_USER` after each execution
    address public currentUser;

    /// @notice Address for receiving collected fees
    address public feeCollector;

    /// @notice Address for invoking pause
    address public pauser;

    /// @dev Modifier for setting transient `currentUser` address and blocking reentrancy.
    modifier whenReady() {
        if (currentUser != _INIT_CURRENT_USER) revert NotReady();
        currentUser = msg.sender;
        _;
        currentUser = _INIT_CURRENT_USER;
    }

    /// @dev Modifier for checking if a caller has the privilege to pause/unpause this contract
    modifier onlyPauser() {
        if (msg.sender != pauser) revert InvalidPauser();
        _;
    }

    /// @dev Create the router with EIP-712 and the agent implementation contracts
    constructor(
        address wrappedNative,
        address owner_,
        address pauser_,
        address feeCollector_,
        bytes32 agentBytecodeHash_
    ) EIP712('Protocolink', '1') {
        currentUser = _INIT_CURRENT_USER;
        agentImplementation = address(new AgentImplementation(wrappedNative));
        agentBytecodeHash = agentBytecodeHash_;
        constructorInputHash = keccak256(abi.encode(agentImplementation));
        setPauser(pauser_);
        setFeeCollector(feeCollector_);
        transferOwnership(owner_);
    }

    /// @notice Get owner address
    /// @return The owner address
    function owner() public view override(IRouter, Ownable) returns (address) {
        return super.owner();
    }

    /// @notice Get domain separator used for EIP-712
    /// @return The domain separator of Protocolink
    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
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
        // https://github.com/matter-labs/v2-testnet-contracts/blob/main/l2/contracts/L2ContractHelper.sol
        bytes32 hash = keccak256(
            bytes.concat(keccak256("zksyncCreate2"), bytes32(uint256(uint160(address(this)))), bytes32(bytes20(user)), agentBytecodeHash, constructorInputHash)
        );

        return address(uint160(uint256(hash)));
    }

    /// @notice Add a signer whose signature can pass the validation in `executeWithSignature` by owner
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

    /// @notice Rescue ERC-20 tokens in case of stuck tokens by owner
    /// @param token The token address
    /// @param receiver The receiver address
    /// @param amount The amount of tokens to be rescued
    function rescue(address token, address receiver, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(receiver, amount);
    }

    /// @notice Pause `execute` and `executeWithSignature` by pauser
    function pause() external onlyPauser {
        if (currentUser == _PAUSED) revert AlreadyPaused();
        currentUser = _PAUSED;
        emit Paused();
    }

    /// @notice Unpause `execute` and `executeWithSignature` by pauser
    function unpause() external onlyPauser {
        if (currentUser != _PAUSED) revert NotPaused();
        currentUser = _INIT_CURRENT_USER;
        emit Unpaused();
    }

    /// @notice Execute arbitrary logics through the current user's agent. Creates an agent for users if not created.
    ///         Fees are charged in the user's agent based on the scenarios defined in the FeeGenerator contract, which
    ///         calculates fees by logics and msg.value.
    /// @param logics Array of logics to be executed
    /// @param tokensReturn Array of ERC-20 tokens to be returned to the current user
    /// @param referralCode Referral code
    function execute(
        IParam.Logic[] calldata logics,
        address[] calldata tokensReturn,
        uint256 referralCode
    ) external payable whenReady {
        address user = currentUser;
        IAgent agent = agents[user];

        if (address(agent) == address(0)) {
            agent = IAgent(_newAgent(user));
        }

        emit Execute(user, address(agent), referralCode);
        agent.execute{value: msg.value}(logics, tokensReturn);
    }

    /// @notice Execute arbitrary logics through the current user's agent using a signer's signature. Creates an agent
    ///         for users if not created. The fees in logicBatch are off-chain encoded, instead of being calculated by
    ///         the FeeGenerator contract.
    /// @dev Allow whitelisted signers to use custom fee rules and permit the reuse of the signature until the deadline
    /// @param logicBatch A struct containing logics, fees and deadline, signed by a signer using EIP-712
    /// @param signer The signer address
    /// @param signature The signer's signature bytes
    /// @param tokensReturn Array of ERC-20 tokens to be returned to the current user
    /// @param referralCode Referral code
    function executeWithSignature(
        IParam.LogicBatch calldata logicBatch,
        address signer,
        bytes calldata signature,
        address[] calldata tokensReturn,
        uint256 referralCode
    ) external payable whenReady {
        // Verify deadline, signer and signature
        uint256 deadline = logicBatch.deadline;
        if (block.timestamp > deadline) revert SignatureExpired(deadline);
        if (!signers[signer]) revert InvalidSigner(signer);
        if (!signer.isValidSignatureNow(_hashTypedDataV4(logicBatch._hash()), signature)) revert InvalidSignature();

        address user = currentUser;
        IAgent agent = agents[user];

        if (address(agent) == address(0)) {
            agent = IAgent(_newAgent(user));
        }

        emit Execute(user, address(agent), referralCode);
        agent.executeWithSignature{value: msg.value}(logicBatch.logics, logicBatch.fees, tokensReturn);
    }

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

    /// @notice Set the fee collector address that collects fees from each user's agent by owner
    /// @param feeCollector_ The fee collector address
    function setFeeCollector(address feeCollector_) public onlyOwner {
        if (feeCollector_ == address(0)) revert InvalidFeeCollector();
        feeCollector = feeCollector_;
        emit FeeCollectorSet(feeCollector_);
    }

    /// @notice Set the pauser address that can pause `execute` and `executeWithSignature` by owner
    /// @param pauser_ The pauser address
    function setPauser(address pauser_) public onlyOwner {
        if (pauser_ == address(0)) revert InvalidNewPauser();
        pauser = pauser_;
        emit PauserSet(pauser_);
    }
}
