// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Bank.sol";

contract StrickBank is Bank {
    constructor(
        RoleStore _roleStore,
        DataStore _dataStore
    ) Bank(_roleStore, _dataStore) {}
}
