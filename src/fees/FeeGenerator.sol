// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';
import {IParam} from '../interfaces/IParam.sol';
import {IFeeCalculator} from '../interfaces/fees/IFeeCalculator.sol';
import {IFeeGenerator} from '../interfaces/fees/IFeeGenerator.sol';

/// @title Fee generator
/// @notice An abstract contract that generates and calculates fees by logics and msg.value
abstract contract FeeGenerator is IFeeGenerator, Ownable {
    error LengthMismatch();

    event FeeCalculatorSet(bytes4 indexed selector, address indexed to, address indexed feeCalculator);

    /// @dev Flag for identifying any `to` address in `feeCalculators`
    address internal constant _ANY_TO_ADDRESS = address(0);

    /// @dev Flag for identifying the native fee calculator
    bytes4 internal constant _NATIVE_FEE_SELECTOR = 0xeeeeeeee;

    /// @notice Mapping for storing fee calculators for each combination of selector and to address
    mapping(bytes4 selector => mapping(address to => address feeCalculator)) public feeCalculators;

    /// @notice Get updated logics and msg.value with the fees included
    /// @param logics The original logics
    /// @param msgValue The original msg.value
    /// @return Updated logics and msg.value with the fees included
    function getLogicsAndMsgValueWithFee(
        IParam.Logic[] memory logics,
        uint256 msgValue
    ) external view returns (IParam.Logic[] memory, uint256) {
        // Update logics
        logics = getLogicsWithFee(logics);

        // Update value
        msgValue = getMsgValueWithFee(msgValue);

        return (logics, msgValue);
    }

    /// @notice Set fee calculators
    /// @param selectors The selectors of `Logic.data`
    /// @param tos The addresses of `Logic.to`
    /// @param feeCalculators_ The fee calculator addresses
    function setFeeCalculators(
        bytes4[] calldata selectors,
        address[] calldata tos,
        address[] calldata feeCalculators_
    ) external onlyOwner {
        uint256 length = selectors.length;
        if (length != tos.length) revert LengthMismatch();
        if (length != feeCalculators_.length) revert LengthMismatch();

        for (uint256 i; i < length; ) {
            bytes4 selector = selectors[i];
            address to = tos[i];
            address feeCalculator = feeCalculators_[i];
            setFeeCalculator(selector, to, feeCalculator);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Set a fee calculator
    /// @param selector The selector of `Logic.data`
    /// @param to The address of `Logic.to`
    /// @param feeCalculator The fee calculator address
    function setFeeCalculator(bytes4 selector, address to, address feeCalculator) public onlyOwner {
        feeCalculators[selector][to] = feeCalculator;
        emit FeeCalculatorSet(selector, to, feeCalculator);
    }

    /// @notice Get updated logics with the fees included
    /// @param logics The original logics
    /// @return Updated logics with the fees included
    function getLogicsWithFee(IParam.Logic[] memory logics) public view returns (IParam.Logic[] memory) {
        uint256 length = logics.length;
        for (uint256 i; i < length; ) {
            bytes memory data = logics[i].data;
            bytes4 selector = bytes4(data);
            address to = logics[i].to;
            address feeCalculator = getFeeCalculator(selector, to);

            if (feeCalculator != address(0)) {
                logics[i].data = IFeeCalculator(feeCalculator).getDataWithFee(data);
            }

            unchecked {
                ++i;
            }
        }

        return logics;
    }

    /// @notice Get updated msg.value with the fees included
    /// @param msgValue The original msg.value
    /// @return Updated msg.value with the fees included
    function getMsgValueWithFee(uint256 msgValue) public view returns (uint256) {
        address nativeFeeCalculator = getNativeFeeCalculator();
        if (msgValue > 0 && nativeFeeCalculator != address(0)) {
            msgValue = uint256(bytes32(IFeeCalculator(nativeFeeCalculator).getDataWithFee(abi.encodePacked(msgValue))));
        }
        return msgValue;
    }

    /// @notice Get the fee calculator for a specific selector and to address
    /// @param selector The selector of `Logic.data`
    /// @param to The address of `Logic.to`
    /// @return feeCalculator The fee calculator address
    function getFeeCalculator(bytes4 selector, address to) public view returns (address feeCalculator) {
        feeCalculator = feeCalculators[selector][to];
        if (feeCalculator == address(0)) {
            feeCalculator = feeCalculators[selector][_ANY_TO_ADDRESS];
        }
    }

    /// @notice Get the native fee calculator
    /// @return nativeFeeCalculator The native fee calculator address
    function getNativeFeeCalculator() public view returns (address nativeFeeCalculator) {
        nativeFeeCalculator = feeCalculators[_NATIVE_FEE_SELECTOR][_ANY_TO_ADDRESS];
    }
}
