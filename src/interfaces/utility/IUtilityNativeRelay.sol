// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUtilityNativeRelay {
    error InvalidAmount();
    error InvalidLength();
    error LengthMismatch();
    error FailedToSendEther();
    error InsufficientBalance(uint256 amount);

    event Transfer(address indexed sender, uint256 receipientCount, uint256 totalValue);

    /// @notice Withdraw all balances in the contract
    /// @dev Only the owner has access
    function withdraw() external;

    /// @notice Send 'amount' native token to 'recipient'
    /// @dev The msg.value must be greater than the amount value
    /// @param recipient The address of the native token recipient
    /// @param amount The amount of the native token
    function send(address payable recipient, uint256 amount) external payable;

    /// @notice Multi-send native token to 'recipients' with same 'amount'
    /// @dev The msg.value must be greater than the sum value
    /// @param recipients The address array of the native token recipients
    /// @param amount The amount of native token sent each time
    function multiSendFixedAmount(address payable[] calldata recipients, uint256 amount) external payable;

    /// @notice Multi-send 'amount' native token to 'recipient'
    /// @dev The msg.value must be greater than the sum value
    /// @param recipients The address array of the native token recipients
    /// @param amounts The amount array of native token
    function multiSendDiffAmount(address payable[] calldata recipients, uint256[] calldata amounts) external payable;
}
