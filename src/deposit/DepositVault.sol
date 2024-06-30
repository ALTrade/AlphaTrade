// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../bank/StrickBank.sol";

contract DepositVault is StrickBank {
    constructor(
        RoleStore _roleStore,
        DataStore _dataStore
    ) StrickBank(_roleStore, _dataStore) {}
}
