// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';
import {IParam} from '../../src/interfaces/IParam.sol';
import {SpenderERC721Approval, ISpenderERC721Approval} from '../../src/SpenderERC721Approval.sol';

contract SpenderERC721Utils is Test {
    ISpenderERC721Approval public erc721Spender;
    address private _erc721User;

    function spenderERC721SetUp(address user_, address router_) internal {
        _erc721User = user_;
        erc721Spender = new SpenderERC721Approval(router_);
    }

    function permitERC721Token(address token) internal {
        vm.prank(_erc721User);
        IERC721(token).setApprovalForAll(address(erc721Spender), true);
    }

    function logicSpenderERC721PullToken(address token, uint256 tokenId) internal view returns (IParam.Logic memory) {
        IParam.Input[] memory inputsEmpty;
        return
            IParam.Logic(
                address(erc721Spender), // to
                abi.encodeWithSelector(erc721Spender.pullToken.selector, token, tokenId),
                inputsEmpty,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
