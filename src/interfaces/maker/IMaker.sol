// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMakerManager {
    function cdpCan(address, uint, address) external view returns (uint);

    function owns(uint) external view returns (address);
}

interface IMakerGemJoin {
    function gem() external view returns (address);
}
