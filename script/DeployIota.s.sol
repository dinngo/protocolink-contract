// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployRouter} from './DeployRouter.s.sol';

contract DeployIota is DeployRouter {
    address public constant DEPLOYER = 0xBcb909975715DC8fDe643EE44b89e3FD6A35A259;
    address public constant OWNER = 0xcE245455a34a57548F7c1F427233DFC1E84Ce1b3;
    address public constant PAUSER = 0xcE245455a34a57548F7c1F427233DFC1E84Ce1b3;
    address public constant DEFAULT_COLLECTOR = 0xFB20753f85f89be6F42D228667D70e62D1Ba5f75;
    address public constant CREATE3_FACTORY = 0xFa3e9a110E6975ec868E9ed72ac6034eE4255B64;

    /// @notice Set up deploy parameters and deploy contracts whose `deployedAddress` equals `UNDEPLOYED`.
    function setUp() external {
        routerConfig = RouterConfig({
            deployedAddress: 0xDec80E988F4baF43be69c13711453013c212feA8,
            wrappedNative: 0x6e47f8d48a01b44DF3fFF35d258A10A3AEdC114c,
            permit2: 0x8d8B490fCe6Ca1A31752E7cFAFa954Bf30eB7EE2,
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
        _deployRouter(CREATE3_FACTORY);
    }
}
