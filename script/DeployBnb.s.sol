// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployRouter} from './DeployRouter.s.sol';
import {DeployRadiantV2FlashLoanCallback} from './callbacks/DeployRadiantV2FlashLoanCallback.s.sol';

contract DeployBnb is DeployRouter, DeployRadiantV2FlashLoanCallback {
    address public constant DEPLOYER = 0xBcb909975715DC8fDe643EE44b89e3FD6A35A259;
    address public constant OWNER = 0x681B7d3470156a8fA6DAf282979d3864b5007b5d;
    address public constant PAUSER = 0x2A57fA8Ec5681a7A96f6070ee360BfD85dFC5bd4;
    address public constant DEFAULT_COLLECTOR = 0xFB20753f85f89be6F42D228667D70e62D1Ba5f75;
    address public constant CREATE3_FACTORY = 0xFa3e9a110E6975ec868E9ed72ac6034eE4255B64;

    /// @notice Set up deploy parameters and deploy contracts whose `deployedAddress` equals `UNDEPLOYED`.
    function setUp() external {
        routerConfig = RouterConfig({
            deployedAddress: 0xDec80E988F4baF43be69c13711453013c212feA8,
            wrappedNative: 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            deployer: DEPLOYER,
            owner: OWNER,
            pauser: PAUSER,
            defaultCollector: DEFAULT_COLLECTOR,
            signer: 0xffFf5a88840FF1f168E163ACD771DFb292164cFA,
            feeRate: 20
        });

        radiantV2FlashLoanCallbackConfig = RadiantV2FlashLoanCallbackConfig({
            deployedAddress: 0x6bfCE075A1c4F0fD4067A401dA8f159354e1a916,
            radiantV2Provider: 0x63764769dA006395515c3f8afF9c91A809eF6607,
            feeRate: 5
        });
    }

    function _run() internal override {
        // router
        address deployedRouterAddress = _deployRouter(CREATE3_FACTORY);

        // callback
        _deployRadiantV2FlashLoanCallback(CREATE3_FACTORY, deployedRouterAddress);
    }
}
