// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';
import {EIP712} from 'openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol';
import {SignatureChecker} from 'openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol';
import {IAgent, AgentImplementation} from './AgentImplementation.sol';
import {Agent} from './Agent.sol';
import {IParam} from './interfaces/IParam.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {LogicHash} from './libraries/LogicHash.sol';
import {IFeeCalculator} from './interfaces/IFeeCalculator.sol';

/// @title Router executes arbitrary logics
contract Router is IRouter, EIP712, Ownable {
    using LogicHash for IParam.LogicBatch;
    using SignatureChecker for address;

    address private constant _INIT_USER = address(1);
    address private constant _INVALID_PAUSER = address(0);
    address private constant _INVALID_FEE_COLLECTOR = address(0);
    uint256 private constant _INVALID_REFERRAL = 0;
    bytes4 private constant _NATIVE_FEE_SELECTOR = 0xeeeeeeee;

    address public immutable agentImplementation;

    mapping(address owner => IAgent agent) public agents;
    mapping(address signer => uint256 referral) public signerReferrals;
    mapping(bytes4 selector => address feeCalculator) public feeCalculators;
    address public user;
    address public feeCollector;
    address public pauser;
    bool public paused;

    modifier checkCaller() {
        if (user == _INIT_USER) {
            user = msg.sender;
        } else {
            revert Reentrancy();
        }
        _;
        user = _INIT_USER;
    }

    modifier isPaused() {
        if (paused) revert RouterIsPaused();
        _;
    }

    modifier onlyPauser() {
        if (msg.sender != pauser) revert InvalidPauser();
        _;
    }

    constructor(address pauser_, address feeCollector_) EIP712('Composable Router', '1') {
        user = _INIT_USER;
        agentImplementation = address(new AgentImplementation());
        _setPauser(pauser_);
        _setFeeCollector(feeCollector_);
    }

    function owner() public view override(IRouter, Ownable) returns (address) {
        return super.owner();
    }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function getAgent() external view returns (address) {
        return address(agents[user]);
    }

    function getAgent(address owner_) external view returns (address) {
        return address(agents[owner_]);
    }

    function getUserAgent() external view returns (address, address) {
        address _user = user;
        return (_user, address(agents[_user]));
    }

    function calcAgent(address owner_) external view returns (address) {
        address result = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            bytes32(bytes20((uint160(owner_)))),
                            keccak256(abi.encodePacked(type(Agent).creationCode, abi.encode(agentImplementation)))
                        )
                    )
                )
            )
        );
        return result;
    }

    /// @notice Get logics and msg.value that contains fee
    function getLogicsWithFee(
        IParam.Logic[] memory logics,
        uint256 msgValue
    ) external view returns (IParam.Logic[] memory, uint256) {
        // Update logics
        uint256 length = logics.length;
        for (uint256 i = 0; i < length; ) {
            bytes memory data = logics[i].data;
            bytes4 selector = bytes4(data);
            address feeCalculator = feeCalculators[selector];
            if (feeCalculator != address(0)) {
                // Get transaction data with fee
                logics[i].data = IFeeCalculator(feeCalculator).getDataWithFee(data);
            }
            unchecked {
                ++i;
            }
        }

        // Update value
        if (msgValue > 0) {
            address nativeFeeCalculator = feeCalculators[_NATIVE_FEE_SELECTOR];
            if (nativeFeeCalculator != address(0)) {
                (, uint256[] memory fees) = IFeeCalculator(nativeFeeCalculator).getFees(abi.encodePacked(msgValue));
                msgValue += fees[0];
            }
        }

        return (logics, msgValue);
    }

    function addSigner(address signer, uint256 referral) external onlyOwner {
        if (referral == _INVALID_REFERRAL) revert InvalidReferral(referral);
        signerReferrals[signer] = referral;

        emit SignerAdded(signer, referral);
    }

    function removeSigner(address signer) external onlyOwner {
        delete signerReferrals[signer];

        emit SignerRemoved(signer);
    }

    /// @notice Set fee calculator contract for each function selector
    function setFeeCalculators(bytes4[] calldata selectors, address[] calldata feeCalculators_) external onlyOwner {
        uint256 length = selectors.length;
        if (length != feeCalculators_.length) revert LengthMismatch();

        for (uint256 i = 0; i < length; ) {
            bytes4 selector = selectors[i];
            address feeCalculator = feeCalculators_[i];
            feeCalculators[selector] = feeCalculator;
            emit FeeCalculatorSet(selector, feeCalculator);
            unchecked {
                ++i;
            }
        }
    }

    function setFeeCollector(address feeCollector_) external onlyOwner {
        _setFeeCollector(feeCollector_);
    }

    function _setFeeCollector(address feeCollector_) internal {
        if (feeCollector_ == _INVALID_FEE_COLLECTOR) revert InvalidFeeCollector();
        feeCollector = feeCollector_;
        emit FeeCollectorSet(feeCollector_);
    }

    function setPauser(address pauser_) external onlyOwner {
        _setPauser(pauser_);
    }

    function _setPauser(address pauser_) internal {
        if (pauser_ == _INVALID_PAUSER) revert InvalidNewPauser();
        pauser = pauser_;
        emit PauserSet(pauser_);
    }

    function pause() external onlyPauser {
        paused = true;
        emit Paused();
    }

    function resume() external onlyPauser {
        paused = false;
        emit Resumed();
    }

    /// @notice Execute logics through user's agent. Create agent for user if not created.
    function execute(
        IParam.Logic[] calldata logics,
        address[] calldata tokensReturn
    ) external payable isPaused checkCaller {
        IAgent agent = agents[user];

        if (address(agent) == address(0)) {
            agent = IAgent(newAgent(user));
        }

        agent.execute{value: msg.value}(logics, tokensReturn, true);
    }

    /// @notice Execute logics with signer's signature.
    function executeWithSignature(
        IParam.LogicBatch calldata logicBatch,
        address signer,
        bytes calldata signature,
        address[] calldata tokensReturn
    ) external payable isPaused checkCaller {
        // Verify deadline, signer and signature
        uint256 deadline = logicBatch.deadline;
        if (block.timestamp > deadline) revert SignatureExpired(deadline);
        if (signerReferrals[signer] == _INVALID_REFERRAL) revert InvalidSigner(signer);
        if (!signer.isValidSignatureNow(_hashTypedDataV4(logicBatch._hash()), signature)) revert InvalidSignature();

        IAgent agent = agents[user];

        if (address(agent) == address(0)) {
            agent = IAgent(newAgent(user));
        }

        agent.execute{value: msg.value}(logicBatch.logics, tokensReturn, false);
    }

    /// @notice Create an agent for `msg.sender`
    function newAgent() external returns (address payable) {
        return newAgent(msg.sender);
    }

    /// @notice Create an agent for `owner_`
    function newAgent(address owner_) public returns (address payable) {
        if (address(agents[owner_]) != address(0)) {
            revert AgentCreated();
        } else {
            IAgent agent = IAgent(address(new Agent{salt: bytes32(bytes20((uint160(owner_))))}(agentImplementation)));
            agents[owner_] = agent;
            return payable(address(agent));
        }
    }
}
