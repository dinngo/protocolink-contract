// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC1155} from 'openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol';
import {IParam} from '../../src/interfaces/IParam.sol';
import {SpenderERC1155Approval, ISpenderERC1155Approval} from '../../src/SpenderERC1155Approval.sol';

contract SpenderERC1155Utils is Test {
    ISpenderERC1155Approval public erc1155Spender;
    address private _erc1155User;

    function spenderERC1155SetUp(address user_, address router_) internal {
        _erc1155User = user_;
        erc1155Spender = new SpenderERC1155Approval(router_);
    }

    function permitERC1155Token(address token) internal {
        vm.prank(_erc1155User);
        IERC1155(token).setApprovalForAll(address(erc1155Spender), true);
    }

    function logicSpenderERC1155PullToken(
        address token,
        uint256 tokenId,
        uint256 amount
    ) internal view returns (IParam.Logic memory) {
        IParam.Input[] memory inputsEmpty;
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        tokenIds[0] = tokenId;
        amounts[0] = amount;

        return
            IParam.Logic(
                address(erc1155Spender), // to
                abi.encodeWithSelector(erc1155Spender.pullToken.selector, token, tokenIds, amounts),
                inputsEmpty,
                address(0) // callback
            );
    }
}
