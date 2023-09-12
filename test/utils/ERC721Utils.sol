// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC721} from 'lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';
import {DataType} from 'src/libraries/DataType.sol';

contract ERC721Utils is Test {
    address internal _erc721User;
    address internal _erc721Agent;

    function erc721UtilsSetUp(address user_, address agent_) internal {
        _erc721User = user_;
        _erc721Agent = agent_;
    }

    function permitERC721Token(address token) internal {
        vm.prank(_erc721User);
        IERC721(token).setApprovalForAll(address(_erc721Agent), true);
    }

    function logicERC721PullToken(address token, uint256 tokenId) internal view returns (DataType.Logic memory) {
        DataType.Input[] memory inputsEmpty;
        return
            DataType.Logic(
                address(token), // to
                abi.encodeWithSignature(
                    'safeTransferFrom(address,address,uint256)',
                    _erc721User,
                    _erc721Agent,
                    tokenId
                ),
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
