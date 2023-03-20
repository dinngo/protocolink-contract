// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAaveV3Provider {
    function getPool() external view returns (address);
}
