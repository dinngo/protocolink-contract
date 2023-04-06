// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAaveV2Provider} from 'src/interfaces/aaveV2/IAaveV2Provider.sol';
import {IAaveV3Provider} from 'src/interfaces/aaveV3/IAaveV3Provider.sol';

contract MockAaveProvider is IAaveV2Provider, IAaveV3Provider {
    address public aavePool;

    constructor(address aavePool_) {
        aavePool = aavePool_;
    }

    function getLendingPool() external view returns (address) {
        return aavePool;
    }

    function getPool() external view returns (address) {
        return aavePool;
    }
}
