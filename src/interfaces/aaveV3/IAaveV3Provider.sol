// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IAaveV3Provider {
    function getPool() external view returns (address);
}
