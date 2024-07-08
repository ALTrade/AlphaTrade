// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../role/RoleStore.sol";
import "../data/DataStore.sol";
import "../bank/Bank.sol";

contract MarketToken is ERC20, Bank {
    constructor(RoleStore _roleStore, DataStore _dataStore) ERC20("Alpha Trade", "AT") Bank(_roleStore, _dataStore) {}

    function mint(address account, uint256 amount) external onlyController {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyController {
        _burn(account, amount);
    }
}
