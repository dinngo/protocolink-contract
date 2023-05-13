// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IParam2} from './IParam2.sol';

interface IFeeCalculator2 {
    /// @notice Get fee array by `to` and `data`
    function getFees(address to, bytes calldata data) external view returns (IParam2.Fee[] memory);

    /// @notice Return updated `data` that contains fee
    function getDataWithFee(bytes calldata data) external view returns (bytes memory);
}
