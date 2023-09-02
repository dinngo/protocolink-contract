// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {SafeERC20, IERC20, Address} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IAllowanceTransfer} from 'permit2/interfaces/IAllowanceTransfer.sol';
import {DataType} from 'src/libraries/DataType.sol';

library FeeLibrary {
    using Address for address payable;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 internal constant BPS_BASE = 10_000;

    event Charged(address indexed token, uint256 amount, bytes32 metadata);

    function pay(DataType.Fee memory fee, address feeCollector) internal {
        address token = fee.token;
        uint256 amount = fee.amount;
        if (amount == 0) {
            return;
        } else if (token == NATIVE) {
            payable(feeCollector).sendValue(amount);
        } else {
            IERC20(token).safeTransfer(feeCollector, amount);
        }

        emit Charged(token, amount, fee.metadata);
    }

    /// @dev Notice that fee should not be NATIVE and should be verified before calling
    function payFrom(DataType.Fee memory fee, address from, address feeCollector, address permit2) internal {
        address token = fee.token;
        uint256 amount = fee.amount;
        if (amount == 0) return;
        IAllowanceTransfer(permit2).transferFrom(from, feeCollector, amount.toUint160(), token);

        emit Charged(token, amount, fee.metadata);
    }

    function getFee(
        address token,
        uint256 amountWithFee,
        uint256 feeRate,
        bytes32 metadata
    ) internal pure returns (DataType.Fee memory) {
        return DataType.Fee(token, calcFeeFromAmountWithFee(amountWithFee, feeRate), metadata);
    }

    function calcFee(
        address token,
        uint256 amount,
        uint256 feeRate,
        bytes32 metadata
    ) internal pure returns (DataType.Fee memory) {
        return DataType.Fee(token, calcFeeFromAmount(amount, feeRate), metadata);
    }

    function calcFeeFromAmountWithFee(uint256 amountWithFee, uint256 feeRate) internal pure returns (uint256) {
        return (amountWithFee * feeRate) / (BPS_BASE + feeRate);
    }

    function calcFeeFromAmount(uint256 amount, uint256 feeRate) internal pure returns (uint256) {
        return (amount * feeRate) / (BPS_BASE);
    }

    function calcAmountWithFee(uint256 amount, uint256 feeRate) internal pure returns (uint256) {
        return (amount * (BPS_BASE + feeRate)) / BPS_BASE;
    }
}
