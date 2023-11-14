// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {SafeCast} from 'lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {SafeERC20, IERC20, Address} from 'lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC721Holder} from 'lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol';
import {ERC1155Holder} from 'lib/openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol';
import {IAllowanceTransfer} from 'lib/permit2/src/interfaces/IAllowanceTransfer.sol';
import {IAgent} from './interfaces/IAgent.sol';
import {DataType} from './libraries/DataType.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {IWrappedNative} from './interfaces/IWrappedNative.sol';
import {ApproveHelper} from './libraries/ApproveHelper.sol';
import {FeeLibrary} from './libraries/FeeLibrary.sol';
import {CallbackLibrary} from './libraries/CallbackLibrary.sol';

/// @title Agent implementation contract
/// @notice Delegated by all users' agents
contract AgentImplementation is IAgent, ERC721Holder, ERC1155Holder {
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using Address for address;
    using Address for address payable;
    using FeeLibrary for DataType.Fee;
    using CallbackLibrary for bytes32;

    /// @dev Flag for identifying the fee source used only for event
    bytes32 internal constant _PERMIT_FEE_META_DATA = bytes32(bytes('permit2:pull-token'));
    bytes32 internal constant _NATIVE_FEE_META_DATA = bytes32(bytes('native-token'));

    /// @dev Flag for identifying the native address such as ETH on Ethereum
    address internal constant _NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @dev Denominator for calculating basis points
    uint256 internal constant _BPS_BASE = 10_000;

    /// @dev Flag for identifying when basis points calculation is not applied
    uint256 internal constant _BPS_NOT_USED = 0;

    /// @dev Dust for evaluating token returns
    uint256 internal constant _DUST = 10;

    /// @dev Flag for identifying no replacement of the amount by setting the most significant bit to 1 (1<<255)
    uint256 internal constant _OFFSET_NOT_USED = 0x8000000000000000000000000000000000000000000000000000000000000000;

    /// @notice Immutable address for recording the router address
    address public immutable router;

    /// @notice Immutable address for recording wrapped native address such as WETH on Ethereum
    address public immutable wrappedNative;

    /// @notice Immutable address for recording permit2 address
    address public immutable permit2;

    /// @dev Transient packed address and flag for recording a valid callback and a charge fee flag
    bytes32 internal _callbackWithCharge;

    /// @dev Create the agent implementation contract
    constructor(address wrappedNative_, address permit2_) {
        router = msg.sender;
        wrappedNative = wrappedNative_;
        permit2 = permit2_;
    }

    /// @notice Initialize user's agent and can only be called once.
    function initialize() external {
        if (_callbackWithCharge.isInitialized()) revert Initialized();
        _callbackWithCharge = CallbackLibrary.INIT_CALLBACK_WITH_CHARGE;
    }

    /// @notice Execute arbitrary logics and is only callable by the router. Charge fee during the execution of
    ///         msg.value, permit2 and flash loans.
    /// @dev The router is designed to prevent reentrancy so additional prevention is not needed here
    /// @param permit2Datas Array of datas to be processed through permit2 contract
    /// @param logics Array of logics to be executed
    /// @param tokensReturn Array of ERC-20 tokens to be returned to the current user
    function execute(
        bytes[] calldata permit2Datas,
        DataType.Logic[] calldata logics,
        address[] calldata tokensReturn
    ) external payable {
        if (msg.sender != router) revert NotRouter();
        _doPermit2(permit2Datas, true);
        _chargeByMsgValue();
        _executeLogics(logics, true);
        _returnTokens(tokensReturn);
    }

    /// @notice Execute arbitrary logics and is only callable by the router using a signer's signature
    /// @dev The router is designed to prevent reentrancy so additional prevention is not needed here
    /// @param logics Array of logics to be executed
    /// @param permit2Datas Array of datas to be processed through permit2 contract
    /// @param fees Array of fees
    /// @param referrals Array of referral to be applied when charging fees
    /// @param tokensReturn Array of ERC-20 tokens to be returned to the current user
    function executeWithSignerFee(
        bytes[] calldata permit2Datas,
        DataType.Logic[] calldata logics,
        DataType.Fee[] calldata fees,
        bytes32[] calldata referrals,
        address[] calldata tokensReturn
    ) external payable {
        if (msg.sender != router) revert NotRouter();
        _doPermit2(permit2Datas, false);
        for (uint256 i; i < referrals.length; ) {
            _charge(fees, referrals[i], false);
            unchecked {
                ++i;
            }
        }
        _executeLogics(logics, false);
        _returnTokens(tokensReturn);
    }

    /// @notice Execute arbitrary logics and is only callable by a valid callback.
    /// @dev A valid callback address is set during `_executeLogics` and reset here
    /// @param logics Array of logics to be executed
    function executeByCallback(DataType.Logic[] calldata logics) external payable {
        bytes32 callbackWithCharge = _callbackWithCharge;

        // Revert if msg.sender is not equal to the callback address
        if (!callbackWithCharge.isCallback(msg.sender)) revert NotCallback();

        // Reset immediately to prevent reentrancy
        // If reentrancy is not blocked, an attacker could manipulate the callback contract to compel agent to execute
        // malicious logic, such as transferring funds from agents and users.
        _callbackWithCharge = CallbackLibrary.INIT_CALLBACK_WITH_CHARGE;

        // Execute logics with the charge fee flag
        _executeLogics(logics, callbackWithCharge.isCharging());
    }

    /// @notice Return current fee charging status when calling
    function isCharging() external view returns (bool) {
        return _callbackWithCharge.isCharging();
    }

    function _doPermit2(bytes[] calldata permit2Datas, bool shouldCharge) internal {
        for (uint256 i; i < permit2Datas.length; ) {
            bytes calldata permit2Data = permit2Datas[i];
            bytes4 selector = bytes4(permit2Data[:4]);
            if (selector == 0x36c78516) {
                // transferFrom(address,address,uint160,address)
                permit2.functionCall(permit2Data, 'ERROR_PERMIT2_TF');
                if (shouldCharge) {
                    uint256 feeRate = IRouter(router).feeRate();
                    (, , uint160 amount, address token) = abi.decode(
                        permit2Data[4:],
                        (address, address, uint160, address)
                    );
                    DataType.Fee[] memory fees = new DataType.Fee[](1);
                    fees[0] = FeeLibrary.getFee(token, amount, feeRate, _PERMIT_FEE_META_DATA);
                    _charge(fees, IRouter(router).defaultReferral(), true);
                }
            } else if (selector == 0x0d58b1db) {
                // transferFrom((address,address,uint160,address)[])
                permit2.functionCall(permit2Data, 'ERROR_PERMIT2_TF');
                if (shouldCharge) {
                    uint256 feeRate = IRouter(router).feeRate();
                    IAllowanceTransfer.AllowanceTransferDetails[] memory details = abi.decode(
                        permit2Data[4:],
                        (IAllowanceTransfer.AllowanceTransferDetails[])
                    );
                    uint256 detailsLength = details.length;
                    DataType.Fee[] memory fees = new DataType.Fee[](detailsLength);
                    for (uint256 j; j < detailsLength; ) {
                        IAllowanceTransfer.AllowanceTransferDetails memory detail = details[j];
                        fees[j] = FeeLibrary.getFee(detail.token, detail.amount, feeRate, _PERMIT_FEE_META_DATA);
                        unchecked {
                            ++j;
                        }
                    }
                    _charge(fees, IRouter(router).defaultReferral(), true);
                }
            } else if (selector == 0x2b67b570 || selector == 0x2a2d80d1) {
                // permit(address,((address,uint160,uint48,uint48),address,uint256),bytes)
                // permit(address,((address,uint160,uint48,uint48)[],address,uint256),bytes)
                permit2.functionCall(permit2Data, 'ERROR_PERMIT2_P');
            } else {
                revert InvalidPermit2Data(selector);
            }

            unchecked {
                ++i;
            }
        }
    }

    function _executeLogics(DataType.Logic[] calldata logics, bool chargeOnCallback) internal {
        // Execute each logic
        uint256 logicsLength = logics.length;
        for (uint256 i; i < logicsLength; ) {
            address to = logics[i].to;
            bytes memory data = logics[i].data;
            DataType.Input[] calldata inputs = logics[i].inputs;
            DataType.WrapMode wrapMode = logics[i].wrapMode;
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
                // 1. if balanceBps is `_BPS_NOT_USED`, then `amountOrOffset` is interpreted directly as the amount.
                // 2. if balanceBps isn't `_BPS_NOT_USED`, then the amount is calculated by the balance with bps
                uint256 amount;
                if (balanceBps == _BPS_NOT_USED) {
                    amount = inputs[j].amountOrOffset;
                } else {
                    if (balanceBps > _BPS_BASE) revert InvalidBps();

                    if (token == wrappedNative && wrapMode == DataType.WrapMode.WRAP_BEFORE) {
                        // Use the native balance for amount calculation as wrap will be executed later
                        amount = (address(this).balance * balanceBps) / _BPS_BASE;
                    } else {
                        amount = (_getBalance(token) * balanceBps) / _BPS_BASE;
                    }

                    // Check if the calculated amount should replace the data at the offset. For most protocols that use
                    // `msg.value` to pass the native amount, use `_OFFSET_NOT_USED` to indicate no replacement.
                    uint256 offset = inputs[j].amountOrOffset;
                    if (offset != _OFFSET_NOT_USED) {
                        if (offset + 0x24 > data.length) revert InvalidOffset(); // 0x24 = 0x4(selector) + 0x20(amount)
                        assembly {
                            let loc := add(add(data, 0x24), offset) // 0x24 = 0x20(data_length) + 0x4(selector)
                            mstore(loc, amount)
                        }
                    }
                    emit AmountReplaced(i, j, amount);
                }

                if (token == wrappedNative && wrapMode == DataType.WrapMode.WRAP_BEFORE) {
                    // Use += to accumulate amounts with multiple WRAP_BEFORE, although such cases are rare
                    wrappedAmount += amount;
                }

                if (token == _NATIVE) {
                    value += amount;
                } else if (token != approveTo) {
                    ApproveHelper.approveMax(token, approveTo, amount);
                }

                unchecked {
                    ++j;
                }
            }

            if (wrapMode == DataType.WrapMode.WRAP_BEFORE) {
                // Wrap native before the call
                IWrappedNative(wrappedNative).deposit{value: wrappedAmount}();
            } else if (wrapMode == DataType.WrapMode.UNWRAP_AFTER) {
                // Or store the before wrapped native amount for calculation after the call
                wrappedAmount = _getBalance(wrappedNative);
            }

            // Set callback who should enter one-time `executeByCallback`
            if (logics[i].callback != address(0)) {
                _callbackWithCharge = CallbackLibrary.getFlag(logics[i].callback, chargeOnCallback);
            }

            // Execute and send native
            if (data.length == 0) {
                payable(to).sendValue(value);
            } else {
                to.functionCallWithValue(data, value, 'ERROR_ROUTER_EXECUTE');
            }

            // Revert if the previous call didn't enter `executeByCallback`
            if (!_callbackWithCharge.isReset()) revert UnresetCallbackWithCharge();

            // Unwrap to native after the call
            if (wrapMode == DataType.WrapMode.UNWRAP_AFTER) {
                IWrappedNative(wrappedNative).withdraw(_getBalance(wrappedNative) - wrappedAmount);
            }

            unchecked {
                ++i;
            }
        }
    }

    function _chargeByMsgValue() internal {
        if (msg.value == 0) return;
        uint256 feeRate = IRouter(router).feeRate();
        bytes32 defaultReferral = IRouter(router).defaultReferral();
        DataType.Fee memory fee = FeeLibrary.getFee(_NATIVE, msg.value, feeRate, _NATIVE_FEE_META_DATA);
        fee.pay(defaultReferral);
    }

    function _charge(DataType.Fee[] memory fees, bytes32 referral, bool payFromAgent) internal {
        uint256 length = fees.length;
        if (length == 0) return;

        for (uint256 i; i < length; ) {
            address token = fees[i].token;
            if (token == _NATIVE || payFromAgent) {
                fees[i].pay(referral);
            } else {
                fees[i].payFrom(IRouter(router).currentUser(), referral, permit2);
            }
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
                    if (address(this).balance > 0) {
                        payable(user).sendValue(address(this).balance);
                    }
                } else {
                    uint256 balance = IERC20(token).balanceOf(address(this));
                    if (balance > _DUST) {
                        IERC20(token).safeTransfer(user, balance);
                    }
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
}
