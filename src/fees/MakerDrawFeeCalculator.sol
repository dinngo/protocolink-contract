// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FeeBase} from './FeeBase.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';

contract MakerDrawFeeCalculator is IFeeCalculator, FeeBase {
    address public daiToken;

    constructor(address router, uint256 feeRate, address daiToken_) FeeBase(router, feeRate) {
        daiToken = daiToken_;
    }

    function getFee(bytes calldata data) external view returns (address, uint256) {
        // Maker draw signature:'draw(address,uint256,uint256)', selector:0xf07ab7be
        (, , uint256 wad) = abi.decode(data, (address, uint256, uint256));
        return (daiToken, calculateFee(wad));
    }

    function getDataWithFee(bytes calldata data) external view returns (bytes memory) {
        (address daiJoin, uint256 cdp, uint256 wad) = abi.decode(data, (address, uint256, uint256));
        wad = calculateAmountWithFee(wad);
        return abi.encode(daiJoin, cdp, wad);
    }
}
