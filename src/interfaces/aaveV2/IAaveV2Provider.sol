// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAaveV2Provider {
    function getLendingPool() external view returns (address);
}
