// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FeeCalculatorBase} from './FeeCalculatorBase.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';
import {IParam} from '../interfaces/IParam.sol';

contract MakerDrawFeeCalculator is IFeeCalculator, FeeCalculatorBase {
    bytes32 internal constant _META_DATA = bytes32(bytes('maker:borrow'));
    bytes4 internal constant _DRAW_FUNCTION_SELECTOR =
        bytes4(keccak256(bytes('draw(address,address,address,uint256,uint256)')));
    uint256 private constant _DRAW_SELECTOR_START_INDEX = 100;
    uint256 private constant _DRAW_SELECTOR_END_INDEX = 104;
    uint256 private constant _DRAW_DATA_START_INDEX = 104;
    uint256 private constant _DRAW_DATA_END_INDEX = 264;

    address public daiToken;

    constructor(address router, uint256 feeRate, address daiToken_) FeeCalculatorBase(router, feeRate) {
        daiToken = daiToken_;
    }

    function getFees(address to, bytes calldata data) external view returns (IParam.Fee[] memory) {
        to;

        // DSProxy execute signature:'execute(address,bytes)', selector:0x1cff79cd
        // Maker draw signature:'draw(address,address,address,uint256,uint256)', selector:0x9f6f3d5b

        // Return if length not enough
        if (data.length <= _DRAW_SELECTOR_END_INDEX) return new IParam.Fee[](0);

        bytes4 selector = bytes4(data[_DRAW_SELECTOR_START_INDEX:_DRAW_SELECTOR_END_INDEX]);

        // Return if selector not match
        if (selector != _DRAW_FUNCTION_SELECTOR) return new IParam.Fee[](0);

        (, , , , uint256 amount) = abi.decode(
            data[_DRAW_DATA_START_INDEX:_DRAW_DATA_END_INDEX],
            (address, address, address, uint256, uint256)
        );

        IParam.Fee[] memory fees = new IParam.Fee[](1);
        fees[0] = IParam.Fee({token: daiToken, amount: calculateFee(amount), metadata: _META_DATA});
        return fees;
    }

    function getDataWithFee(bytes calldata data) external view returns (bytes memory) {
        // Return if length not enough
        if (data.length <= _DRAW_SELECTOR_END_INDEX) return data;

        bytes4 selector = bytes4(data[_DRAW_SELECTOR_START_INDEX:_DRAW_SELECTOR_END_INDEX]);

        // Return if selector not match
        if (selector != _DRAW_FUNCTION_SELECTOR) return data;

        // Decode data
        (address cdpManager, address jug, address daiJoin, uint256 cdp, uint256 amount) = abi.decode(
            data[_DRAW_DATA_START_INDEX:_DRAW_DATA_END_INDEX],
            (address, address, address, uint256, uint256)
        );

        amount = calculateAmountWithFee(amount);

        // Encode data back
        return
            abi.encodePacked(
                data[:_DRAW_DATA_START_INDEX],
                abi.encode(cdpManager, jug, daiJoin, cdp, amount),
                data[_DRAW_DATA_END_INDEX:]
            );
    }
}
