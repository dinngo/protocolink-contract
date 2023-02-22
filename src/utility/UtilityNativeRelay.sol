// SPDX-License-Idnetifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';
import {IUtilityNativeRelay} from '../interfaces/utility/IUtilityNativeRelay.sol';

/// @title Utilities for sending native tokens
contract UtilityNativeRelay is IUtilityNativeRelay, Ownable {
    function withdraw() external onlyOwner {
        _send(payable(msg.sender), address(this).balance);
    }

    function send(address payable recipient, uint256 amount) external payable {
        if (amount == 0) revert InvalidAmount();
        if (msg.value < amount) revert InsufficientBalance(msg.value);

        _send(recipient, amount);
        emit Transfer(msg.sender, 1, msg.value);
    }

    function multiSendFixedAmount(address payable[] calldata recipients, uint256 amount) external payable {
        if (recipients.length == 0) revert InvalidLength();
        if (amount == 0) revert InvalidAmount();
        if (msg.value < recipients.length * amount) revert InsufficientBalance(msg.value);

        uint256 length = recipients.length;

        for (uint256 i = 0; i < length; ) {
            _send(recipients[i], amount);
            unchecked {
                ++i;
            }
        }
        emit Transfer(msg.sender, length, msg.value);
    }

    function multiSendDiffAmount(address payable[] calldata recipients, uint256[] calldata amounts) external payable {
        if (recipients.length == 0) revert InvalidLength();
        if (recipients.length != amounts.length) revert LengthMismatch();

        uint256 length = recipients.length;
        uint256 currentSum = 0;

        for (uint256 i = 0; i < length; ) {
            uint256 amount = amounts[i];
            if (amount == 0) revert InvalidAmount();
            currentSum = currentSum + amount;
            if (msg.value < currentSum) revert InsufficientBalance(msg.value);
            _send(recipients[i], amount);
            unchecked {
                ++i;
            }
        }
        emit Transfer(msg.sender, length, msg.value);
    }

    function _send(address payable recipient, uint256 amount) internal {
        (bool success, ) = recipient.call{value: amount}('');
        if (!success) revert FailedToSendEther();
    }
}
