// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FeeBase} from './FeeBase.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';

contract MakerDrawFeeCalculator is IFeeCalculator, FeeBase {
    bytes4 private constant _DRAW_FUNCTION_SELECTOR =
        bytes4(keccak256(bytes('draw(address,address,address,uint256,uint256)')));

    address public daiToken;

    constructor(address router, uint256 feeRate, address daiToken_) FeeBase(router, feeRate) {
        daiToken = daiToken_;
    }

    function getFees(bytes calldata data) external view returns (address[] memory, uint256[] memory) {
        // DSProxy execute signature:'execute(address,bytes)', selector:0x1cff79cd
        // Maker draw signature:'draw(address,address,address,uint256,uint256)', selector:0x9f6f3d5b
        (, bytes memory makerActionData) = abi.decode(data, (address, bytes));
        bytes4 selector = bytes4(makerActionData);
        if (selector == _DRAW_FUNCTION_SELECTOR) {
            (, , , , uint256 amount) = abi.decode(makerActionData, (address, address, address, uint256, uint256));

            address[] memory tokens = new address[](1);
            tokens[0] = daiToken;

            uint256[] memory fees = new uint256[](1);
            fees[0] = calculateFee(amount);
            return (tokens, fees);
        } else {
            return (new address[](0), new uint256[](0));
        }
    }

    function getDataWithFee(bytes calldata data) external view returns (bytes memory) {
        (address proxyAction, bytes memory makerActionData) = abi.decode(data, (address, bytes));
        bytes4 selector = bytes4(makerActionData);
        if (selector == _DRAW_FUNCTION_SELECTOR) {
            (address cdpManager, address jug, address daiJoin, uint256 cdp, uint256 amount) = abi.decode(
                makerActionData,
                (address, address, address, uint256, uint256)
            );
            amount = calculateAmountWithFee(amount);
            return abi.encode(proxyAction, abi.encode(cdpManager, jug, daiJoin, cdp, amount));
        } else {
            return data;
        }
    }
}
