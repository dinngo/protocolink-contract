// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {Address} from 'lib/openzeppelin-contracts/contracts/utils/Address.sol';
import {IWrappedNative} from 'src/interfaces/IWrappedNative.sol';

contract MockWrappedNative is IWrappedNative, ERC20('Wrapped Native', 'WNATIVE') {
    using Address for address payable;

    event Deposit(address indexed from, uint256 amount);
    event Withdrawal(address indexed to, uint256 amount);

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        payable(msg.sender).sendValue(amount);

        emit Withdrawal(msg.sender, amount);
    }
}
