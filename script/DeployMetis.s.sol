// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployRouter} from './DeployRouter.s.sol';
import {DeployAaveV3FlashLoanCallback} from './callbacks/DeployAaveV3FlashLoanCallback.s.sol';

contract DeployMetis is DeployRouter, DeployAaveV3FlashLoanCallback {
    address public constant DEPLOYER = 0xBcb909975715DC8fDe643EE44b89e3FD6A35A259;
    address public constant OWNER = 0xcE245455a34a57548F7c1F427233DFC1E84Ce1b3;
    address public constant PAUSER = 0xcE245455a34a57548F7c1F427233DFC1E84Ce1b3;
    address public constant DEFAULT_COLLECTOR = 0x75Ce960F2FD5f06C83EE034992362e593dcf7722;
    address public constant CREATE3_FACTORY = 0xFa3e9a110E6975ec868E9ed72ac6034eE4255B64;

    /// @notice Set up deploy parameters and deploy contracts whose `deployedAddress` equals `UNDEPLOYED`.
    function setUp() external {
        routerConfig = RouterConfig({
            deployedAddress: 0xDec80E988F4baF43be69c13711453013c212feA8,
            wrappedNative: 0x75cb093E4D61d2A2e65D8e0BBb01DE8d89b53481,
            permit2: 0x2EE5407017B878774b58c34A8c09CAcC94aDd69B,
            deployer: DEPLOYER,
            owner: OWNER,
            pauser: PAUSER,
            defaultCollector: DEFAULT_COLLECTOR,
            signer: 0xffFf5a88840FF1f168E163ACD771DFb292164cFA,
            feeRate: 20
        });

        aaveV3FlashLoanCallbackConfig = AaveV3FlashLoanCallbackConfig({
            deployedAddress: 0x6f81cf774052D03873b32944a036BF0647bFB5bF,
            aaveV3Provider: 0xB9FABd7500B2C6781c35Dd48d54f81fc2299D7AF,
            feeRate: 5
        });
    }

    function _run() internal override {
        // router
        address deployedRouterAddress = _deployRouter(CREATE3_FACTORY);

        // callback
        _deployAaveV3FlashLoanCallback(CREATE3_FACTORY, deployedRouterAddress);
    }
}
