// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC1155} from 'openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol';
import {IParam} from '../../src/interfaces/IParam.sol';

contract SpenderERC1155Utils is Test {
    address private _erc1155User;
    address private _erc1155Spender;

    function spenderERC1155SetUp(address user_, address agent_) internal {
        _erc1155User = user_;
        _erc1155Spender = agent_;
    }

    function permitERC1155Token(address token) internal {
        vm.prank(_erc1155User);
        IERC1155(token).setApprovalForAll(address(_erc1155Spender), true);
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
                address(token), // to
                abi.encodeWithSignature("safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)", _erc1155User, _erc1155Spender, tokenIds, amounts, ''),
                inputsEmpty,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
