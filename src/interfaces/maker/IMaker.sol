// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMakerManager {
    function cdpCan(address, uint, address) external view returns (uint);

    function ilks(uint) external view returns (bytes32);

    function owns(uint) external view returns (address);

    function urns(uint) external view returns (address);
}

interface IMakerVat {
    function ilks(bytes32) external view returns (uint, uint, uint, uint, uint);

    function urns(bytes32, address) external view returns (uint, uint);
}

interface IMakerGemJoin {
    function gem() external view returns (address);
}
