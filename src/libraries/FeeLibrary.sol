// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {SafeCast} from 'lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {SafeERC20, IERC20, Address} from 'lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IAllowanceTransfer} from 'lib/permit2/src/interfaces/IAllowanceTransfer.sol';
import {DataType} from './DataType.sol';

library FeeLibrary {
    using Address for address payable;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 internal constant BPS_BASE = 10_000;

    event Charged(address indexed token, uint256 amount, address indexed collector, bytes32 metadata);

    function pay(DataType.Fee memory fee, bytes32 referral) internal {
        uint256 amount = fee.amount;
        if (amount == 0) return;
        address token = fee.token;
        (address collector, uint256 rate) = _parse(referral);
        if (rate != BPS_BASE) amount = (amount * rate) / BPS_BASE;
        if (token == NATIVE) {
            payable(collector).sendValue(amount);
        } else {
            IERC20(token).safeTransfer(collector, amount);
        }

        emit Charged(token, amount, collector, fee.metadata);
    }

    function payFrom(DataType.Fee memory fee, address from, bytes32 referral, address permit2) internal {
        uint256 amount = fee.amount;
        if (amount == 0) return;
        address token = fee.token;
        (address collector, uint256 rate) = _parse(referral);
        if (rate != BPS_BASE) amount = (amount * rate) / BPS_BASE;
        IAllowanceTransfer(permit2).transferFrom(from, collector, amount.toUint160(), token);

        emit Charged(token, amount, collector, fee.metadata);
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

    function _parse(bytes32 referral) private pure returns (address, uint256) {
        return (address(bytes20(referral)), uint256(uint16(uint256(referral))));
    }
}
