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
import {IFeeDecodeContract} from './interfaces/IFeeDecodeContract.sol';

/// @title Router executes arbitrary logics
contract Router is IRouter, EIP712, Ownable {
    using LogicHash for IParam.LogicBatch;
    using SignatureChecker for address;

    address private constant _INIT_USER = address(1);
    uint256 private constant _INVALID_REFERRAL = 0;
    address public constant ANY_ADDRESS = address(0xff);
    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant FEE_RATE = 20;

    address public immutable agentImplementation;

    mapping(address owner => IAgent agent) public agents;
    mapping(address signer => uint256 referral) public signerReferrals;
    mapping(bytes4 selector => mapping(address to => address feeDecodeContract)) public feeDecoder;
    mapping(bytes4 selector => bool) public feeChargeSelector;
    address public user;

    modifier checkCaller() {
        if (user == _INIT_USER) {
            user = msg.sender;
        } else {
            revert Reentrancy();
        }
        _;
        user = _INIT_USER;
    }
    
    constructor() EIP712('Composable Router', '1'){
        user = _INIT_USER;
        agentImplementation = address(new AgentImplementation());
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

    function addSigner(address signer, uint256 referral) external onlyOwner {
        if (referral == _INVALID_REFERRAL) revert InvalidReferral(referral);
        signerReferrals[signer] = referral;

        emit SignerAdded(signer, referral);
    }

    function removeSigner(address signer) external onlyOwner {
        delete signerReferrals[signer];

        emit SignerRemoved(signer);
    }

    /// @notice Execute logics with signer's signature.
    function executeWithSignature(
        IParam.LogicBatch calldata logicBatch,
        address signer,
        bytes calldata signature,
        address[] calldata tokensReturn
    ) external payable {
        // Verify deadline, signer and signature
        uint256 deadline = logicBatch.deadline;
        if (block.timestamp > deadline) revert SignatureExpired(deadline);
        if (signerReferrals[signer] == _INVALID_REFERRAL) revert InvalidSigner(signer);
        if (!signer.isValidSignatureNow(_hashTypedDataV4(logicBatch._hash()), signature)) revert InvalidSignature();

        execute(logicBatch.logics, tokensReturn);
    }

    /// @notice Execute logics through user's agent. Create agent for user if not created.
    function execute(IParam.Logic[] calldata logics, address[] calldata tokensReturn) public payable checkCaller {
        IAgent agent = agents[user];

        if (address(agent) == address(0)) {
            agent = IAgent(newAgent(user));
        }

        agent.execute{value: msg.value}(logics, tokensReturn);
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

    function setFeeDecoder(bytes4[] calldata selector, address[] calldata tos, address[] calldata feeDecodeContracts) public onlyOwner{
        uint256 length = selector.length;
        require(length == tos.length);
        require(length == feeDecodeContracts.length);

        for(uint256 i = 0; i < length; ){
            feeDecoder[selector[i]][tos[i]] = feeDecodeContracts[i];
            feeChargeSelector[selector[i]] = true;
            unchecked{
                ++i;
            }
        }
    }
    // Verify fees by decreasing memory fees which should be 0 in the end
    function verifyFees(IParam.Logic[] calldata logics, IParam.Fee[] memory fees) internal view {
        uint256 feesLength = fees.length;
        uint256 logicsLength = logics.length;
        for (uint256 i = 0; i < logicsLength; ) {
            bytes calldata data = logics[i].data;
            // TODO: charge native

            // Check if selector need charge
            bytes4 selector = bytes4(data[:4]);
            if(feeChargeSelector[selector] == false){
                unchecked{
                    ++i;
                }
                continue;
            }

            // Check if `to` need charge    
            mapping(address to => address feeDecodeContract) storage feeDecodeContracts = feeDecoder[selector];
            address to = logics[i].to;
            address decodeContract = feeDecodeContracts[to];
            decodeContract = decodeContract != address(0)? decodeContract : feeDecodeContracts[ANY_ADDRESS]; 
            if(decodeContract == address(0)){
                unchecked{
                    ++i;
                }
                continue;
            }

            // Deduct fee
            (address asset, uint256 amount) = IFeeDecodeContract(decodeContract).decodeData(data);
            for (uint256 j = 0; j < feesLength; ) {
                if (fees[j].token == asset) {
                    fees[j].feeAmount -= (amount * FEE_RATE) / BPS_BASE;
                    break;
                }
                
                unchecked{
                    ++j;
                }
            }

            unchecked{
                ++i;
            }
        }

        // Verify all fee amounts are 0 to ensure the fees are valid
        for (uint256 i = 0; i < feesLength; ) {
            require(fees[i].feeAmount == 0, 'fee is not enough');
            unchecked{
                ++i;
            }
        }
    }
    
}
