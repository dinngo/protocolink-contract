// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {SafeERC20, IERC20, Address} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IAllowanceTransfer} from 'permit2/interfaces/IAllowanceTransfer.sol';
import {IParam} from 'src/interfaces/IParam.sol';

library FeeLibrary {
    using Address for address payable;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 internal constant BPS_BASE = 10_000;

    event FeeCharged(address indexed token, uint256 amount, bytes32 metadata);

    function pay(IParam.Fee memory fee, address feeCollector) internal {
        address token = fee.token;
        uint256 amount = fee.amount;
        if (amount == 0) {
            return;
        } else if (token == NATIVE) {
            payable(feeCollector).sendValue(amount);
        } else {
            IERC20(token).safeTransfer(feeCollector, amount);
        }

        emit FeeCharged(token, amount, fee.metadata);
    }

    /// @dev Notice that fee should not be NATIVE and should be verified before calling
    function payFrom(IParam.Fee memory fee, address from, address feeCollector, address permit2) internal {
        address token = fee.token;
        uint256 amount = fee.amount;
        if (amount == 0) return;
        IAllowanceTransfer(permit2).transferFrom(from, feeCollector, amount.toUint160(), token);

        emit FeeCharged(token, amount, fee.metadata);
    }

    function getFee(
        address token,
        uint256 amountWithFee,
        uint256 feeRate,
        bytes32 metadata
    ) internal pure returns (IParam.Fee memory) {
        return IParam.Fee(token, calculateFeeFromAmountWithFee(amountWithFee, feeRate), metadata);
    }

    function calculateFee(
        address token,
        uint256 amount,
        uint256 feeRate,
        bytes32 metadata
    ) internal pure returns (IParam.Fee memory) {
        return IParam.Fee(token, calculateFeeFromAmount(amount, feeRate), metadata);
    }

    function calculateFeeFromAmountWithFee(uint256 amountWithFee, uint256 feeRate) internal pure returns (uint256) {
        return (amountWithFee * feeRate) / (BPS_BASE + feeRate);
    }

    function calculateFeeFromAmount(uint256 amount, uint256 feeRate) internal pure returns (uint256) {
        return (amount * feeRate) / (BPS_BASE);
    }

    function calculateAmountWithFee(uint256 amount, uint256 feeRate) internal pure returns (uint256) {
        return (amount * (BPS_BASE + feeRate)) / BPS_BASE;
    }
}
