// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDSProxy {
    function execute(address _target, bytes calldata _data) external payable returns (bytes32 response);
}

interface IDSProxyRegistry {
    function proxies(address input) external view returns (address);

    function build() external returns (address);
}
