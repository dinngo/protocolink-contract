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

    /// @dev Flag for identifying the native address such as ETH on Ethereum
    address internal constant _NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @dev Denominator for calculating basis points
    uint256 internal constant _BPS_BASE = 10_000;

    /// @notice Immutable address for recording the router address
    address public immutable router;

    /// @notice Immutable address for recording wrapped native address such as WETH on Ethereum
    address public immutable wrappedNative;

    /// @notice Transient address for recording a valid caller which should be the router address after each execution
    address internal _caller;

    modifier checkCaller() {
        address caller = _caller;
        // Only predefined caller can call agent
        if (caller != msg.sender) revert InvalidCaller();

        // When the caller is not router, should be reset right away to guarantee one-time usage from callback contracts
        if (caller != router) {
            _caller = router;
        }
        _;
    }

    modifier handleUnWrap(IParam2.Logic calldata logic) {
        bool isUnWrapMode = logic.isUnWrapMode();
        uint256 wrappedAmount;
        if (isUnWrapMode) {
            // Or store the before wrapped native amount for calculation after the call
            wrappedAmount = _getBalance(wrappedNative);
        }

        _;

        if (isUnWrapMode) {
            IWrappedNative(wrappedNative).withdraw(_getBalance(wrappedNative) - wrappedAmount);
        }
    }

    modifier handleCallback(IParam2.Logic calldata logic) {
        // Set _callback who should enter one-time execute
        if (logic.callback != address(0)) _caller = logic.callback;

        _;

        // Revert if the previous call didn't enter execute
        if (_caller != router) revert UnresetCallback();
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
        // Execute logics
        uint256 logicsLength = logics.length;
        for (uint256 i; i < logicsLength; ) {
            _executeLogics(i, logics[i]);
            unchecked {
                ++i;
            }
        }

        // Charge fee
        _chargeFee(fees);

        // Push tokensReturn if any balance
        _refundTokens(tokensReturn);
    }

    function _getBalance(address token) internal view returns (uint256 balance) {
        if (token == _NATIVE) {
            balance = address(this).balance;
        } else {
            balance = IERC20(token).balanceOf(address(this));
        }
    }

    function _executeLogics(
        uint256 logicIdx,
        IParam2.Logic calldata logic
    ) internal handleUnWrap(logic) handleCallback(logic) {
        // Execute each input if need to modify the amount or do approve
        (uint256 value, bytes memory data) = _parseInputs(logic, logicIdx);

        // Execute and send native
        if (data.length == 0) {
            payable(logic.to).sendValue(value);
        } else {
            logic.to.functionCallWithValue(data, value, 'ERROR_ROUTER_EXECUTE');
        }
    }

    function _parseInputs(IParam2.Logic calldata logic, uint256 i) internal returns (uint256 value, bytes memory data) {
        data = logic.data;
        IParam2.Input[] calldata inputs = logic.inputs;
        address approveTo = logic.getApproveTo();
        bool isWrapMode = logic.isWrapMode();

        // // Default `approveTo` is same as `to` unless `approveTo` is set
        if (approveTo == address(0)) {
            approveTo = logic.to;
        }

        // Execute each input if need to modify the amount or do approve
        uint256 wrappedAmount;
        uint256 inputsLength = logic.inputs.length;
        for (uint256 j = 0; j < inputsLength; ) {
            (address token, uint256 amountBps, bool bpsEnable) = inputs[j].getTokenAndBps();
            // Calculate native or token amount
            // 1. if amountBps is skip: read amountOrOffset as amount
            // 2. if amountBps isn't skip: balance multiplied by amountBps as amount
            uint256 amount;
            if (bpsEnable) {
                if (amountBps > _BPS_BASE) revert InvalidBps();

                if (token == wrappedNative && isWrapMode) {
                    // Use the native balance for amount calculation as wrap will be executed later
                    amount = (address(this).balance * amountBps) / _BPS_BASE;
                } else {
                    amount = (_getBalance(token) * amountBps) / _BPS_BASE;
                }

                if (token != _NATIVE) {
                    // Skip if don't need to replace, e.g., most protocols set native amount in call value
                    uint256 offset = inputs[j].amountOrOffset;
                    // Replace the amount at offset in data with the calculated amount
                    assembly {
                        let loc := add(add(data, 0x24), offset) // 0x24 = 0x20(data_length) + 0x4(sig)
                        mstore(loc, amount)
                    }
                }
                emit AmountReplaced(i, j, amount);
            } else {
                amount = inputs[j].amountOrOffset;
            }

            if (token == wrappedNative && isWrapMode) {
                // Use += to accumulate amounts with multiple WRAP_BEFORE, although such cases are rare
                wrappedAmount += amount;
            }

            // Approve token or update value
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
        }
    }

    function _refundTokens(address[] calldata tokensReturn) internal {
        uint256 tokensReturnLength = tokensReturn.length;
        if (tokensReturnLength > 0) {
            address user = IRouter2(router).currentUser();
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
