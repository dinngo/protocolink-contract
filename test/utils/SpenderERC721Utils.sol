// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';
import {IParam} from 'src/interfaces/IParam.sol';

contract SpenderERC721Utils is Test {
    address internal _erc721User;
    address internal _erc721Spender;

    function spenderERC721SetUp(address user_, address agent_) internal {
        _erc721User = user_;
        _erc721Spender = agent_;
    }

    function permitERC721Token(address token) internal {
        vm.prank(_erc721User);
        IERC721(token).setApprovalForAll(address(_erc721Spender), true);
    }

    function logicSpenderERC721PullToken(address token, uint256 tokenId) internal view returns (IParam.Logic memory) {
        IParam.Input[] memory inputsEmpty;
        return
            IParam.Logic(
                address(token), // to
                abi.encodeWithSignature(
                    'safeTransferFrom(address,address,uint256)',
                    _erc721User,
                    _erc721Spender,
                    tokenId
                ),
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
