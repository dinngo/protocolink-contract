// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC1155} from 'lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol';
import {DataType} from 'src/libraries/DataType.sol';

contract ERC1155Utils is Test {
    address internal _erc1155User;
    address internal _erc1155Agent;

    function erc1155UtilsSetUp(address user_, address agent_) internal {
        _erc1155User = user_;
        _erc1155Agent = agent_;
    }

    function permitERC1155Token(address token) internal {
        vm.prank(_erc1155User);
        IERC1155(token).setApprovalForAll(address(_erc1155Agent), true);
    }

    function logicERC1155PullToken(
        address token,
        uint256 tokenId,
        uint256 amount
    ) internal view returns (DataType.Logic memory) {
        DataType.Input[] memory inputsEmpty;
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        tokenIds[0] = tokenId;
        amounts[0] = amount;

        return
            DataType.Logic(
                address(token), // to
                abi.encodeWithSignature(
                    'safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)',
                    _erc1155User,
                    _erc1155Agent,
                    tokenIds,
                    amounts,
                    ''
                ),
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
