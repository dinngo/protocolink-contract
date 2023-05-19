// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';
import {IParam} from '../interfaces/IParam.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';

/// @title Fee generator
/// @notice An abstract contract that generates and calculates fees on-chain
abstract contract FeeGenerator is Ownable {
    error LengthMismatch();

    event FeeCalculatorSet(bytes4 indexed selector, address indexed to, address indexed feeCalculator);

    address internal constant _DUMMY_TO_ADDRESS = address(0);

    /// @dev Flag for identifying the native fee calculator
    bytes4 internal constant _NATIVE_FEE_SELECTOR = 0xeeeeeeee;

    /// @notice Mapping for storing fee calculators for each combination of selector and to address
    mapping(bytes4 selector => mapping(address to => address feeCalculator)) public feeCalculators;

    /// @notice Get logics and msg.value that contains fee
    function getUpdatedLogicsAndMsgValue(
        IParam.Logic[] memory logics,
        uint256 msgValue
    ) external view returns (IParam.Logic[] memory, uint256) {
        // Update logics
        logics = getLogicsDataWithFee(logics);

        // Update value
        msgValue = getMsgValueWithFee(msgValue);

        return (logics, msgValue);
    }

    /// @notice Set fee calculator contracts
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

    function setFeeCalculator(bytes4 selector, address to, address feeCalculator) public onlyOwner {
        feeCalculators[selector][to] = feeCalculator;
        emit FeeCalculatorSet(selector, to, feeCalculator);
    }

    function getLogicsDataWithFee(IParam.Logic[] memory logics) public view returns (IParam.Logic[] memory) {
        uint256 length = logics.length;
        for (uint256 i; i < length; ) {
            bytes memory data = logics[i].data;
            bytes4 selector = bytes4(data);
            address to = logics[i].to;
            address feeCalculator = getFeeCalculator(selector, to);

            // Get transaction data with fee
            if (feeCalculator != address(0)) {
                logics[i].data = IFeeCalculator(feeCalculator).getDataWithFee(data);
            }

            unchecked {
                ++i;
            }
        }

        return logics;
    }

    function getMsgValueWithFee(uint256 msgValue) public view returns (uint256) {
        IFeeCalculator nativeFeeCalculator = getNativeFeeCalculator();
        if (msgValue > 0 && address(nativeFeeCalculator) != address(0)) {
            msgValue = uint256(bytes32(nativeFeeCalculator.getDataWithFee(abi.encodePacked(msgValue))));
        }
        return msgValue;
    }

    function getFeesByLogics(IParam.Logic[] memory logics, uint256 msgValue) public view returns (IParam.Fee[] memory) {
        IParam.Fee[] memory tempFees = new IParam.Fee[](32); // Create a temporary `tempFees` with size 32 to store fee
        uint256 realFeeLength;
        uint256 logicsLength = logics.length;
        for (uint256 i; i < logicsLength; ++i) {
            bytes memory data = logics[i].data;
            bytes4 selector = bytes4(data);
            address to = logics[i].to;

            // Get feeCalculator
            address feeCalculator = getFeeCalculator(selector, to);
            if (feeCalculator == address(0)) continue; // No need to charge fee

            // Get charge tokens and amounts
            IParam.Fee[] memory feesByLogic = IFeeCalculator(feeCalculator).getFees(to, data);
            uint256 feesByLogicLength = feesByLogic.length;
            if (feesByLogicLength == 0) {
                continue; // No need to charge fee
            }

            for (uint256 feeIndex = 0; feeIndex < feesByLogicLength; ++feeIndex) {
                tempFees[realFeeLength++] = feesByLogic[feeIndex];
            }
        }

        // For native fee
        IFeeCalculator nativeFeeCalculator = getNativeFeeCalculator();
        if (msgValue > 0 && address(nativeFeeCalculator) != address(0)) {
            tempFees[realFeeLength++] = nativeFeeCalculator.getFees(_DUMMY_TO_ADDRESS, abi.encodePacked(msgValue))[0];
        }

        // Copy tempFees to fees
        IParam.Fee[] memory fees = new IParam.Fee[](realFeeLength);
        for (uint256 i; i < realFeeLength; ++i) {
            fees[i] = tempFees[i];
        }

        return fees;
    }

    function getFeeCalculator(bytes4 selector, address to) public view returns (address feeCalculator) {
        feeCalculator = feeCalculators[selector][to];
        if (feeCalculator == address(0)) {
            feeCalculator = feeCalculators[selector][_DUMMY_TO_ADDRESS];
        }
    }

    function getNativeFeeCalculator() internal view returns (IFeeCalculator) {
        address nativeFeeCalculator = feeCalculators[_NATIVE_FEE_SELECTOR][_DUMMY_TO_ADDRESS];
        return IFeeCalculator(nativeFeeCalculator);
    }
}
