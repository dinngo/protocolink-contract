// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IParam} from '../IParam.sol';

interface IFeeCalculator {
    /// @notice Get fee array by `to` and `data`
    function getFees(address to, bytes calldata data) external view returns (IParam.Fee[] memory);

    /// @notice Return updated `data` with fee included
    function getDataWithFee(bytes calldata data) external view returns (bytes memory);
}
