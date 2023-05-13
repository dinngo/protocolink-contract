// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {SafeERC20, IERC20, Address} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC721Holder} from 'openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol';
import {ERC1155Holder} from 'openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol';
import {IAgent2} from './interfaces/IAgent2.sol';
import {IParam2} from './interfaces/IParam2.sol';
import {IRouter2} from './interfaces/IRouter2.sol';
import {IWrappedNative} from './interfaces/IWrappedNative.sol';
import {ApproveHelper} from './libraries/ApproveHelper.sol';
import {LogicHelper, InputHelper} from './libraries/Param2Helper.sol';

/// @title Agent implementation contract
/// @notice Delegated by all users' agents
contract AgentImplementation2 is IAgent2, ERC721Holder, ERC1155Holder {
    using SafeERC20 for IERC20;
    using Address for address;
    using Address for address payable;
    using LogicHelper for IParam2.Logic;
    using InputHelper for IParam2.Input;

    // bytes32 internal constant BPS_VALUE_MASK_ = 0x0000000000000000000000000000000000000000ffff00000000000000000000;

    /// @dev Flag for identifying the native address such as ETH on Ethereum
    address internal constant _NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @dev Denominator for calculating basis points
    uint256 internal constant _BPS_BASE = 10_000;

    /// @dev Flag for indicating a skipped value by setting the most significant bit to 1 (1<<255)
    uint256 internal constant _BPS_SKIP = 0;

    /// @notice Immutable address for recording the router address
    address public immutable router;

    /// @notice Immutable address for recording wrapped native address such as WETH on Ethereum
    address public immutable wrappedNative;

    /// @notice Transient address for recording a valid caller which should be the router address after each execution
    address internal _caller;

    modifier checkCaller() {
        address caller = _caller;
        if (caller != msg.sender) {
            // Only predefined caller can call agent
            revert InvalidCaller();
        } else if (caller != router) {
            // When the caller is not router, should be reset right away to guarantee one-time usage from callback contracts
            _caller = router;
        }
        _;
    }

    /// @dev Create the agent implementation contract
    constructor(address wrappedNative_) {
        router = msg.sender;
        wrappedNative = wrappedNative_;
    }

    /// @notice Initialize user's agent and can only be called once.
    function initialize() external {
        if (_caller != address(0)) revert Initialized();
        _caller = router;
    }

    /// @notice Execute arbitrary logics
    /// @param logics Array of logics to be executed
    /// @param fees Array of fees
    /// @param tokensReturn Array of ERC-20 tokens to be returned to the current user
    function execute(
        IParam2.Logic[] calldata logics,
        IParam2.Fee[] calldata fees,
        address[] calldata tokensReturn
    ) external payable checkCaller {
        _executeLogics(logics);

        _chargeFee(fees);

        // Push tokensReturn if any balance
        uint256 tokensReturnLength = tokensReturn.length;
        if (tokensReturnLength > 0) {
            address user = IRouter2(router).currentUser();
            for (uint256 i = 0; i < tokensReturnLength; ) {
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

    function _getBalance(address token) internal view returns (uint256 balance) {
        if (token == _NATIVE) {
            balance = address(this).balance;
        } else {
            balance = IERC20(token).balanceOf(address(this));
        }
    }

    function _executeLogics(IParam2.Logic[] calldata logics) internal {
        // Execute each logic
        uint256 logicsLength = logics.length;
        for (uint256 i = 0; i < logicsLength; ) {
            address to = logics[i].to;
            bytes memory data = logics[i].data;
            IParam2.Input[] calldata inputs = logics[i].inputs;
            bool isWrapMode = logics[i].isWrapMode();
            bool isUnWrapMode = logics[i].isUnWrapMode();
            address approveTo = logics[i].getApproveTo();

            // Default `approveTo` is same as `to` unless `approveTo` is set
            if (approveTo == address(0)) {
                approveTo = to;
            }

            // Execute each input if need to modify the amount or do approve
            uint256 value;
            uint256 wrappedAmount;
            uint256 inputsLength = inputs.length;
            for (uint256 j = 0; j < inputsLength; ) {
                // address token = inputs[j].token;
                (address token, uint256 amountBps) = inputs[j].getTokenAndBps();
                // Calculate native or token amount
                // 1. if amountBps is skip: read amountOrOffset as amount
                // 2. if amountBps isn't skip: balance multiplied by amountBps as amount
                uint256 amount;
                if (amountBps == _BPS_SKIP) {
                    amount = inputs[j].amountOrOffset;
                } else {
                    if (amountBps > _BPS_BASE) revert InvalidBps();

                    if (token == wrappedNative && isWrapMode) {
                        // Use the native balance for amount calculation as wrap will be executed later
                        amount = (address(this).balance * amountBps) / _BPS_BASE;
                    } else {
                        amount = (_getBalance(token) * amountBps) / _BPS_BASE;
                    }

                    // Q: 判斷是不是 Native Token?
                    if (inputs[j].isReplaceCallData()) {
                        // Skip if don't need to replace, e.g., most protocols set native amount in call value
                        uint256 offset = inputs[j].amountOrOffset;
                        // Replace the amount at offset in data with the calculated amount
                        assembly {
                            let loc := add(add(data, 0x24), offset) // 0x24 = 0x20(data_length) + 0x4(sig)
                            mstore(loc, amount)
                        }
                    }
                    emit AmountReplaced(i, j, amount);
                }

                if (token == wrappedNative && isWrapMode) {
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

            if (isWrapMode) {
                // Wrap native before the call
                IWrappedNative(wrappedNative).deposit{value: wrappedAmount}();
            } else if (isUnWrapMode) {
                // Or store the before wrapped native amount for calculation after the call
                wrappedAmount = _getBalance(wrappedNative);
            }

            // Set _callback who should enter one-time execute
            if (logics[i].callback != address(0)) _caller = logics[i].callback;

            // Execute and send native
            if (data.length == 0) {
                payable(to).sendValue(value);
            } else {
                to.functionCallWithValue(data, value, 'ERROR_ROUTER_EXECUTE');
            }

            // Revert if the previous call didn't enter execute
            if (_caller != router) revert UnresetCallback();

            // Unwrap to native after the call
            if (isUnWrapMode) {
                IWrappedNative(wrappedNative).withdraw(_getBalance(wrappedNative) - wrappedAmount);
            }

            unchecked {
                ++i;
            }
        }
    }

    function _chargeFee(IParam2.Fee[] calldata fees) internal {
        uint256 length = fees.length;
        if (length == 0) return;

        address feeCollector = IRouter2(router).feeCollector();
        for (uint256 i = 0; i < length; ) {
            address token = fees[i].token;
            uint256 amount = fees[i].amount;
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
}
