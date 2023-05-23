// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {SafeERC20, IERC20, Address} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC721Holder} from 'openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol';
import {ERC1155Holder} from 'openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol';
import {IAgent} from './interfaces/IAgent.sol';
import {IParam} from './interfaces/IParam.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {IFeeCalculator} from './interfaces/fees/IFeeCalculator.sol';
import {IFeeGenerator} from './interfaces/fees/IFeeGenerator.sol';
import {IWrappedNative} from './interfaces/IWrappedNative.sol';
import {ApproveHelper} from './libraries/ApproveHelper.sol';

/// @title Agent implementation contract
/// @notice Delegated by all users' agents
contract AgentImplementation is IAgent, ERC721Holder, ERC1155Holder {
    using SafeERC20 for IERC20;
    using Address for address;
    using Address for address payable;

    /// @dev Flag for identifying the initialized state and reducing gas cost when resetting `_callbackWithCharge`
    bytes32 internal constant _INIT_CALLBACK_WITH_CHARGE = bytes32(bytes20(address(1)));

    /// @dev Flag for identifying whether to charge fee determined by the least significant bit of `_callbackWithCharge`
    bytes32 internal constant _CHARGE_MASK = bytes32(uint256(1));

    /// @dev Flag for identifying the native address such as ETH on Ethereum
    address internal constant _NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @dev Flag for identifying any address in router's fee calculators mapping
    address internal constant _ANY_TO_ADDRESS = address(0);

    /// @dev Denominator for calculating basis points
    uint256 internal constant _BPS_BASE = 10_000;

    /// @dev Flag for indicating a skipped value by setting the most significant bit to 1 (1<<255)
    uint256 internal constant _SKIP = 0x8000000000000000000000000000000000000000000000000000000000000000;

    /// @notice Immutable address for recording the router address
    address public immutable router;

    /// @notice Immutable address for recording wrapped native address such as WETH on Ethereum
    address public immutable wrappedNative;

    /// @dev Transient packed address and flag for recording a valid callback and a charge fee flag
    bytes32 internal _callbackWithCharge;

    /// @dev Create the agent implementation contract
    constructor(address wrappedNative_) {
        router = msg.sender;
        wrappedNative = wrappedNative_;
    }

    /// @notice Initialize user's agent and can only be called once.
    function initialize() external {
        if (_callbackWithCharge != bytes32(0)) revert Initialized();
        _callbackWithCharge = _INIT_CALLBACK_WITH_CHARGE;
    }

    /// @notice Execute arbitrary logics and is only callable by the router. Charge fee based on the scenarios defined
    ///         in the router.
    /// @dev The router is designed to prevent reentrancy so additional prevention is not needed here
    /// @param logics Array of logics to be executed
    /// @param tokensReturn Array of ERC-20 tokens to be returned to the current user
    function execute(IParam.Logic[] calldata logics, address[] calldata tokensReturn) external payable {
        if (msg.sender != router) revert NotRouter();

        _chargeFeeByMsgValue();

        _executeLogics(logics, true);

        _returnTokens(tokensReturn);
    }

    /// @notice Execute arbitrary logics and is only callable by the router using a signer's signature
    /// @dev The router is designed to prevent reentrancy so additional prevention is not needed here
    /// @param logics Array of logics to be executed
    /// @param fees Array of fees
    /// @param tokensReturn Array of ERC-20 tokens to be returned to the current user
    function executeWithSignature(
        IParam.Logic[] calldata logics,
        IParam.Fee[] calldata fees,
        address[] calldata tokensReturn
    ) external payable {
        if (msg.sender != router) revert NotRouter();

        _chargeFee(fees);

        _executeLogics(logics, false);

        _returnTokens(tokensReturn);
    }

    /// @notice Execute arbitrary logics and is only callable by a valid callback. Charge fee based on the scenarios
    ///         defined in the router if the charge bit is set.
    /// @dev A valid callback address is set during `_executeLogics` and reset here
    /// @param logics Array of logics to be executed
    function executeByCallback(IParam.Logic[] calldata logics) external payable {
        bytes32 callbackWithCharge = _callbackWithCharge;

        // Revert if msg.sender is not equal to the callback address
        if (msg.sender != address(bytes20(callbackWithCharge))) revert NotCallback();

        // Check the least significant bit to determine whether to charge fee
        bool shouldChargeFeeByLogic = (callbackWithCharge & _CHARGE_MASK) != bytes32(0);

        // Reset immediately to prevent reentrancy
        _callbackWithCharge = _INIT_CALLBACK_WITH_CHARGE;

        // Execute logics with the charge fee flag
        _executeLogics(logics, shouldChargeFeeByLogic);
    }

    function _getBalance(address token) internal view returns (uint256 balance) {
        if (token == _NATIVE) {
            balance = address(this).balance;
        } else {
            balance = IERC20(token).balanceOf(address(this));
        }
    }

    function _executeLogics(IParam.Logic[] calldata logics, bool shouldChargeFeeByLogic) internal {
        // Execute each logic
        uint256 logicsLength = logics.length;
        for (uint256 i; i < logicsLength; ) {
            address to = logics[i].to;
            bytes memory data = logics[i].data;
            IParam.Input[] calldata inputs = logics[i].inputs;
            IParam.WrapMode wrapMode = logics[i].wrapMode;
            address approveTo = logics[i].approveTo;

            // Default `approveTo` is same as `to` unless `approveTo` is set
            if (approveTo == address(0)) {
                approveTo = to;
            }

            // Execute each input if need to modify the amount or do approve
            uint256 value;
            uint256 wrappedAmount;
            uint256 inputsLength = inputs.length;
            for (uint256 j; j < inputsLength; ) {
                address token = inputs[j].token;
                uint256 balanceBps = inputs[j].balanceBps;

                // Calculate native or token amount
                // 1. if balanceBps is skip: read amountOrOffset as amount
                // 2. if balanceBps isn't skip: balance multiplied by balanceBps as amount
                uint256 amount;
                if (balanceBps == _SKIP) {
                    amount = inputs[j].amountOrOffset;
                } else {
                    if (balanceBps == 0 || balanceBps > _BPS_BASE) revert InvalidBps();

                    if (token == wrappedNative && wrapMode == IParam.WrapMode.WRAP_BEFORE) {
                        // Use the native balance for amount calculation as wrap will be executed later
                        amount = (address(this).balance * balanceBps) / _BPS_BASE;
                    } else {
                        amount = (_getBalance(token) * balanceBps) / _BPS_BASE;
                    }

                    // Skip if don't need to replace, e.g., most protocols set native amount in call value
                    uint256 offset = inputs[j].amountOrOffset;
                    if (offset != _SKIP) {
                        // Replace the amount at offset in data with the calculated amount
                        assembly {
                            let loc := add(add(data, 0x24), offset) // 0x24 = 0x20(data_length) + 0x4(sig)
                            mstore(loc, amount)
                        }
                    }
                    emit AmountReplaced(i, j, amount);
                }

                if (token == wrappedNative && wrapMode == IParam.WrapMode.WRAP_BEFORE) {
                    // Use += to accumulate amounts with multiple WRAP_BEFORE, although such cases are rare
                    wrappedAmount += amount;
                }

                if (token == _NATIVE) {
                    value += amount;
                } else if (token != approveTo) {
                    ApproveHelper._approveMax(token, approveTo, amount);
                }

                unchecked {
                    ++j;
                }
            }

            if (wrapMode == IParam.WrapMode.WRAP_BEFORE) {
                // Wrap native before the call
                IWrappedNative(wrappedNative).deposit{value: wrappedAmount}();
            } else if (wrapMode == IParam.WrapMode.UNWRAP_AFTER) {
                // Or store the before wrapped native amount for calculation after the call
                wrappedAmount = _getBalance(wrappedNative);
            }

            // Set callback who should enter one-time `executeByCallback`
            if (logics[i].callback != address(0)) {
                bytes32 callback = bytes32(bytes20(logics[i].callback));
                if (shouldChargeFeeByLogic) {
                    // Set the least significant bit
                    _callbackWithCharge = callback | _CHARGE_MASK;
                } else {
                    _callbackWithCharge = callback;
                }
            }

            // Execute and send native
            if (data.length == 0) {
                payable(to).sendValue(value);
            } else {
                to.functionCallWithValue(data, value, 'ERROR_ROUTER_EXECUTE');
            }

            // Revert if the previous call didn't enter `executeByCallback`
            if (_callbackWithCharge != _INIT_CALLBACK_WITH_CHARGE) revert UnresetCallbackWithCharge();

            if (shouldChargeFeeByLogic) {
                _chargeFeeByLogic(logics[i]);
            }

            // Unwrap to native after the call
            if (wrapMode == IParam.WrapMode.UNWRAP_AFTER) {
                IWrappedNative(wrappedNative).withdraw(_getBalance(wrappedNative) - wrappedAmount);
            }

            unchecked {
                ++i;
            }
        }
    }

    function _chargeFeeByMsgValue() internal {
        if (msg.value == 0) return;

        address nativeFeeCalculator = IFeeGenerator(router).getNativeFeeCalculator();
        if (nativeFeeCalculator != address(0)) {
            _chargeFee(IFeeCalculator(nativeFeeCalculator).getFees(_ANY_TO_ADDRESS, abi.encodePacked(msg.value)));
        }
    }

    function _chargeFeeByLogic(IParam.Logic calldata logic) internal {
        bytes memory data = logic.data;
        bytes4 selector = bytes4(data);
        address to = logic.to;

        address feeCalculator = IFeeGenerator(router).getFeeCalculator(selector, to);
        if (feeCalculator != address(0)) {
            _chargeFee(IFeeCalculator(feeCalculator).getFees(to, data));
        }
    }

    function _chargeFee(IParam.Fee[] memory fees) internal {
        uint256 length = fees.length;
        if (length == 0) return;

        address feeCollector = IRouter(router).feeCollector();
        for (uint256 i; i < length; ) {
            uint256 amount = fees[i].amount;
            if (amount == 0) {
                unchecked {
                    ++i;
                }
                continue;
            }

            address token = fees[i].token;
            if (token == _NATIVE) {
                payable(feeCollector).sendValue(amount);
            } else {
                IERC20(token).safeTransfer(feeCollector, amount);
            }

            emit FeeCharged(token, amount, fees[i].metadata);
            unchecked {
                ++i;
            }
        }
    }

    function _returnTokens(address[] calldata tokensReturn) internal {
        // Return tokens to the current user if any balance
        uint256 tokensReturnLength = tokensReturn.length;
        if (tokensReturnLength > 0) {
            address user = IRouter(router).currentUser();
            for (uint256 i; i < tokensReturnLength; ) {
                address token = tokensReturn[i];
                if (token == _NATIVE) {
                    payable(user).sendValue(address(this).balance);
                } else {
                    uint256 balance = IERC20(token).balanceOf(address(this));
                    IERC20(token).safeTransfer(user, balance);
                }

                unchecked {
                    ++i;
                }
            }
        }
    }
}
