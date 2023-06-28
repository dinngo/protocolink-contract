// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRouter} from "../interfaces/IRouter.sol";

contract MockProtocol {
    IRouter public router;
    constructor(address router_) {
        router = IRouter(router_);
    }
      function checkExecutingAgent(address agent) external view {
        (, address executingAgent) = router.getCurrentUserAgent();
        if (agent != executingAgent) revert();
    }
}
