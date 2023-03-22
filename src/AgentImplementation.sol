// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20, Address} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC721Holder} from 'openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol';
import {ERC1155Holder} from 'openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol';

import {IAgent} from './interfaces/IAgent.sol';
import {IParam} from './interfaces/IParam.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {IFeeCalculator} from './interfaces/IFeeCalculator.sol';
import {ApproveHelper} from './libraries/ApproveHelper.sol';

/// @title Implemtation contract of agent logics
contract AgentImplementation is IAgent, ERC721Holder, ERC1155Holder {
    using SafeERC20 for IERC20;
    using Address for address;
    using Address for address payable;

    event FeeCharged(address indexed token, uint256 amount);

    address private constant _NATIVE = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    bytes4 private constant _NATIVE_FEE_SELECTOR = 0xeeeeeeee;
    bytes private constant _NATIVE_TOKEN_FEE_CHARGE_DATA = '';
    uint256 private constant _BPS_BASE = 10_000;
    uint256 private constant _SKIP = type(uint256).max;

    address public immutable router;

    address private _caller;

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

    constructor() {
        router = msg.sender;
    }

    function initialize() external {
        if (_caller != address(0)) revert Initialized();
        _caller = router;
    }

    /// @notice Execute logics and return tokens to user
    function execute(
        IParam.Logic[] calldata logics,
        address[] calldata tokensReturn,
        bool isFeeEnabled
    ) external payable checkCaller {
        address feeCollector;
        if (isFeeEnabled) feeCollector = IRouter(router).feeCollector();

        // Execute each logic
        uint256 logicsLength = logics.length;
        for (uint256 i = 0; i < logicsLength; ) {
            address to = logics[i].to;
            bytes memory data = logics[i].data;
            IParam.Input[] calldata inputs = logics[i].inputs;
            address approveTo = logics[i].approveTo;
            address callback = logics[i].callback;

            // Default `approveTo` is same as `to` unless `approveTo` is set
            if (approveTo == address(0)) {
                approveTo = to;
            }

            // Execute each input if need to modify the amount or do approve
            uint256 value;
            uint256 inputsLength = inputs.length;
            for (uint256 j = 0; j < inputsLength; ) {
                address token = inputs[j].token;
                uint256 amountBps = inputs[j].amountBps;

                // Calculate native or token amount
                // 1. if amountBps is skip: read amountOrOffset as amount
                // 2. if amountBps isn't skip: balance multiplied by amountBps as amount and replace the amount at offset equal to amountOrOffset with the calculated amount
                uint256 amount;
                if (amountBps == _SKIP) {
                    amount = inputs[j].amountOrOffset;
                } else {
                    if (amountBps == 0 || amountBps > _BPS_BASE) revert InvalidBps();
                    amount = (_getBalance(token) * amountBps) / _BPS_BASE;

                    // Skip if don't need to replace, e.g., most protocols set native amount in call value
                    uint256 offset = inputs[j].amountOrOffset;
                    if (offset != _SKIP) {
                        assembly {
                            let loc := add(add(data, 0x24), offset) // 0x24 = 0x20(data_length) + 0x4(sig)
                            mstore(loc, amount)
                        }
                    }
                }

                // Set native token value for native token
                if (token == _NATIVE) {
                    value = amount;
                } else if (token != approveTo) {
                    ApproveHelper._approveMax(token, approveTo, amount);
                }

                unchecked {
                    ++j;
                }
            }

            // Set _callback who should enter one-time execute
            if (callback != address(0)) _caller = callback;

            // Execute and send native
            if (data.length == 0) {
                payable(to).sendValue(value);
            } else {
                to.functionCallWithValue(data, value, 'ERROR_ROUTER_EXECUTE');
            }

            // Revert if the previous call didn't enter execute
            if (_caller != router) revert UnresetCallback();

            // Charge fees
            if (isFeeEnabled) {
                _chargeFee(data, feeCollector);
            }

            unchecked {
                ++i;
            }
        }

        // Charge native token fee
        if (isFeeEnabled && msg.value > 0) {
            _chargeFee(_NATIVE_TOKEN_FEE_CHARGE_DATA, feeCollector);
        }

        // Push tokensReturn if any balance
        uint256 tokensReturnLength = tokensReturn.length;
        if (tokensReturnLength > 0) {
            address user = IRouter(router).user();
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

    /// @notice Check transaction `data` and charge fee
    function _chargeFee(bytes memory data, address feeCollector) private {
        bool isNative = data.length == 0 ? true : false;
        bytes4 selector = isNative ? _NATIVE_FEE_SELECTOR : bytes4(data);
        address feeCalculator = IRouter(router).feeCalculators(selector);
        if (feeCalculator != address(0)) {
            data = isNative ? abi.encodePacked(msg.value) : data;
            // Get charge token and fee
            (address token, uint256 fee) = IFeeCalculator(feeCalculator).getFee(data);
            if (fee > 0) {
                if (isNative) {
                    payable(feeCollector).sendValue(fee);
                } else {
                    IERC20(token).safeTransfer(feeCollector, fee);
                }
                emit FeeCharged(token, fee);
            }
        }
    }

    function _getBalance(address token) private view returns (uint256 balance) {
        if (token == _NATIVE) {
            balance = address(this).balance;
        } else {
            balance = IERC20(token).balanceOf(address(this));
        }
    }
}
