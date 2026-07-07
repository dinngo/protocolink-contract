// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployRouter} from './DeployRouter.s.sol';

contract DeployChain138Fallback is DeployRouter {
    address public constant DEPLOYER = 0x4A666F96fC8764181194447A7dFdb7d471b301C8;
    address public constant OWNER = 0xcE245455a34a57548F7c1F427233DFC1E84Ce1b3;
    address public constant PAUSER = 0xcE245455a34a57548F7c1F427233DFC1E84Ce1b3;
    address public constant DEFAULT_COLLECTOR = 0xFB20753f85f89be6F42D228667D70e62D1Ba5f75;
    address public constant FALLBACK_CREATE3_FACTORY = 0x486B2E145F486eFA0190a60259B5BB464BD6b22b;
    address public constant FALLBACK_ROUTER = 0xE7f51632381d0791eC5c05F5585e7b1bFf1de5F5;

    /// @notice Fallback Chain 138 Router deploy using a Chain 138-specific CREATE3Factory.
    /// @dev This is not the canonical cross-chain Protocolink Router address path.
    function setUp() external {
        routerConfig = RouterConfig({
            deployedAddress: FALLBACK_ROUTER,
            wrappedNative: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            deployer: DEPLOYER,
            owner: OWNER,
            pauser: PAUSER,
            defaultCollector: DEFAULT_COLLECTOR,
            signer: 0xffFf5a88840FF1f168E163ACD771DFb292164cFA,
            feeRate: 20
        });
    }

    function _run() internal override {
        // router
        _deployRouter(FALLBACK_CREATE3_FACTORY);
    }
}
