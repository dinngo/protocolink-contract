// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';
import {EIP712} from 'openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol';
import {SignatureChecker} from 'openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol';
import {IAgent, AgentImplementation} from './AgentImplementation.sol';
import {Agent} from './Agent.sol';
import {FeeGenerator} from './fees/FeeGenerator.sol';
import {IParam} from './interfaces/IParam.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {LogicHash} from './libraries/LogicHash.sol';

/// @title Entry point for Composable Router
contract Router is IRouter, EIP712, FeeGenerator {
    using SafeERC20 for IERC20;
    using LogicHash for IParam.LogicBatch;
    using SignatureChecker for address;

    /// @dev Flag for reducing gas cost when reset `currentUser`
    address internal constant _INIT_USER = address(1);

    /// @dev Flag for identifying an invalid pauser address
    address internal constant _INVALID_PAUSER = address(0);

    /// @dev Flag for identifying an invalid fee collector address
    address internal constant _INVALID_FEE_COLLECTOR = address(0);

    /// @notice Immutable implementation contract for all users' agents
    address public immutable agentImplementation;

    /// @notice Mapping for recording exclusive agent contract to each user
    mapping(address user => IAgent agent) public agents;

    /// @notice Mapping for recording valid signers
    mapping(address signer => bool valid) public signers;

    /// @notice Transient address for recording `msg.sender` which resets to `_INIT_USER` after each execution
    address public currentUser;

    /// @notice Address for receiving collected fees
    address public feeCollector;

    /// @notice Address for invoking pause
    address public pauser;

    /// @notice Flag for indicating pause
    bool public paused;

    modifier checkCaller() {
        if (currentUser == _INIT_USER) {
            currentUser = msg.sender;
        } else {
            revert Reentrancy();
        }
        _;
        currentUser = _INIT_USER;
    }

    modifier isPaused() {
        if (paused) revert RouterIsPaused();
        _;
    }

    modifier onlyPauser() {
        if (msg.sender != pauser) revert InvalidPauser();
        _;
    }

    /// @dev Create the router with EIP-712 and the agent implementation contracts
    constructor(address wrappedNative, address pauser_, address feeCollector_) EIP712('Composable Router', '1') {
        currentUser = _INIT_USER;
        agentImplementation = address(new AgentImplementation(wrappedNative));
        _setPauser(pauser_);
        _setFeeCollector(feeCollector_);
    }

    /// @notice Get owner address
    /// @return The owner address
    function owner() public view override(IRouter, Ownable) returns (address) {
        return super.owner();
    }

    /// @notice Get domain separator used for EIP-712
    /// @return The domain separator of Composable Router
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
    function getUserAgent() external view returns (address, address) {
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
                            bytes32(bytes20((uint160(user)))),
                            keccak256(abi.encodePacked(type(Agent).creationCode, abi.encode(agentImplementation)))
                        )
                    )
                )
            )
        );
        return result;
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

    /// @notice Set the fee collector address that collects fees from each user's agent by owner
    /// @param feeCollector_ The fee collector address
    function setFeeCollector(address feeCollector_) external onlyOwner {
        _setFeeCollector(feeCollector_);
    }

    function _setFeeCollector(address feeCollector_) internal {
        if (feeCollector_ == _INVALID_FEE_COLLECTOR) revert InvalidFeeCollector();
        feeCollector = feeCollector_;
        emit FeeCollectorSet(feeCollector_);
    }

    /// @notice Set the pauser address that can pause `execute` and `executeWithSignature` by owner
    /// @param pauser_ The pauser address
    function setPauser(address pauser_) external onlyOwner {
        _setPauser(pauser_);
    }

    function _setPauser(address pauser_) internal {
        if (pauser_ == _INVALID_PAUSER) revert InvalidNewPauser();
        pauser = pauser_;
        emit PauserSet(pauser_);
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
        paused = true;
        emit Paused();
    }

    /// @notice Resume `execute` and `executeWithSignature` by pauser
    function resume() external onlyPauser {
        paused = false;
        emit Resumed();
    }

    /// @notice Execute arbitrary logics through the current user's agent. Creates an agent for users if not created.
    ///         Charge fees based on the scenarios defined in the FeeGenerator contract, which calculates fees on-chain.
    /// @param logics Array of logics to be executed
    /// @param tokensReturn Array of ERC-20 tokens to be returned to the current user
    /// @param referralCode Referral code
    function execute(
        IParam.Logic[] calldata logics,
        address[] calldata tokensReturn,
        uint256 referralCode
    ) external payable isPaused checkCaller {
        address user = currentUser;
        IAgent agent = agents[user];

        if (address(agent) == address(0)) {
            agent = IAgent(newAgent(user));
        }

        IParam.Fee[] memory fees = getFeesByLogics(logics, msg.value);

        emit Execute(user, address(agent), referralCode);
        agent.execute{value: msg.value}(logics, fees, tokensReturn);
    }

    /// @notice Execute arbitrary logics through the current user's agent using a signer's signature. Creates an agent
    ///         for users if not created. The fees in logicBatch are off-chain encoded, instead of being calculated by
    ///         the FeeGenerator contract.
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
    ) external payable isPaused checkCaller {
        // Verify deadline, signer and signature
        uint256 deadline = logicBatch.deadline;
        if (block.timestamp > deadline) revert SignatureExpired(deadline);
        if (!signers[signer]) revert InvalidSigner(signer);
        if (!signer.isValidSignatureNow(_hashTypedDataV4(logicBatch._hash()), signature)) revert InvalidSignature();

        address user = currentUser;
        IAgent agent = agents[user];

        if (address(agent) == address(0)) {
            agent = IAgent(newAgent(user));
        }

        emit Execute(user, address(agent), referralCode);
        agent.execute{value: msg.value}(logicBatch.logics, logicBatch.fees, tokensReturn);
    }

    /// @notice Create an agent for `msg.sender`
    /// @return The newly created agent address
    function newAgent() external returns (address payable) {
        return newAgent(msg.sender);
    }

    /// @notice Create an agent for the user
    /// @param user The user address
    /// @return The newly created agent address
    function newAgent(address user) public returns (address payable) {
        if (address(agents[user]) != address(0)) {
            revert AgentAlreadyCreated();
        } else {
            IAgent agent = IAgent(address(new Agent{salt: bytes32(bytes20((uint160(user))))}(agentImplementation)));
            agents[user] = agent;
            emit AgentCreated(address(agent), user);
            return payable(address(agent));
        }
    }
}
