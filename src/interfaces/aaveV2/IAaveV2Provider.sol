// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IAaveV2Provider {
    function getLendingPool() external view returns (address);
}
