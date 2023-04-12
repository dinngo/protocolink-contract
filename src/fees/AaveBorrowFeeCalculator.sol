// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {FeeCalculatorBase} from './FeeCalculatorBase.sol';
import {IAaveV3Provider} from '../interfaces/aaveV3/IAaveV3Provider.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';
import {IParam} from '../interfaces/IParam.sol';

contract AaveBorrowFeeCalculator is IFeeCalculator, FeeCalculatorBase {
    bytes32 internal constant _V2_BORROW_META_DATA = bytes32(bytes('aave-v2:borrow'));
    bytes32 internal constant _V3_BORROW_META_DATA = bytes32(bytes('aave-v3:borrow'));

    address public immutable aaveV3Provider;

    constructor(address router, uint256 feeRate, address aaveV3Provider_) FeeCalculatorBase(router, feeRate) {
        aaveV3Provider = aaveV3Provider_;
    }

    function getFees(address to, bytes calldata data) external view returns (IParam.Fee[] memory) {
        // Aave borrow signature:'borrow(address,uint256,uint256,uint16,address)', selector:0xa415bcad
        (address token, uint256 amount, , , ) = abi.decode(data[4:], (address, uint256, uint256, uint16, address));

        IParam.Fee[] memory fees = new IParam.Fee[](1);
        fees[0] = IParam.Fee({
            token: token,
            amount: calculateFee(amount),
            metadata: to == IAaveV3Provider(aaveV3Provider).getPool() ? _V3_BORROW_META_DATA : _V2_BORROW_META_DATA
        });
        return fees;
    }

    function getDataWithFee(bytes calldata data) external view returns (bytes memory) {
        (address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) = abi.decode(
            data[4:],
            (address, uint256, uint256, uint16, address)
        );
        amount = calculateAmountWithFee(amount);
        return abi.encodePacked(data[:4], abi.encode(asset, amount, interestRateMode, referralCode, onBehalfOf));
    }
}
