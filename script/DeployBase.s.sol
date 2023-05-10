// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {stdJson} from 'forge-std/StdJson.sol';
import {Script} from 'forge-std/Script.sol';

contract DeployBase is Script {
    using stdJson for string;

    error InvalidRouterAddress();
    error InvalidCREATE3FactoryAddress();

    struct DeployParameters {
        address router;
        // role
        address owner;
        address pauser;
        address feeCollector;
        // token
        address wrappedNative;
        address dai;
        // external
        address create3Factory;
        address aaveV2Provider;
        address aaveV3Provider;
        address balancerV2Vault;
        address makerProxyRegistry;
        address makerCdpManager;
        address makerProxyActions;
        address makerJug;
        // fee
        uint256 aaveBorrowFeeCalculatorFeeRate;
        uint256 aaveFlashLoanFeeCalculatorFeeRate;
        uint256 compoundV3BorrowFeeCalculatorFeeRate;
        uint256 makerDrawFeeCalculatorFeeRate;
        uint256 nativeFeeCalculatorFeeRate;
        uint256 permit2FeeCalculatorFeeRate;
        uint256 transferFromFeeCalculatorFeeRate;
    }

    modifier isRouterAddressZero(address router) {
        if (router == address(0)) revert InvalidRouterAddress();
        _;
    }

    modifier isCREATE3FactoryAddressZero(address factory) {
        if (factory == address(0)) revert InvalidCREATE3FactoryAddress();
        _;
    }

    function setUp() external {}

    function run(string memory pathToJSON) external {
        vm.startBroadcast();
        _run(_fetchParameters(pathToJSON));
        vm.stopBroadcast();
    }

    function _run(DeployParameters memory params) internal virtual returns (address deployedAddress) {}

    function _fetchParameters(string memory pathToJSON) internal view returns (DeployParameters memory params) {
        string memory root = vm.projectRoot();
        string memory json = vm.readFile(string.concat(root, '/', pathToJSON));
        bytes memory rawParams = json.parseRaw('.*');
        (, , params) = abi.decode(rawParams, (bytes32, bytes32, DeployParameters));
    }
}
