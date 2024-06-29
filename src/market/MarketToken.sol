// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MarketToken is ERC20 {
    constructor(
        RoleStore _roleStore,
        DataStore _dataStore
    ) ERC20("Alpha Trade", "AT") {}
}
