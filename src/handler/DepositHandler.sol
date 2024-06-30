// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./IDepositHandler.sol";
import "../library/GlobalReentrancyGuard.sol";
import "../role/RoleModule.sol";
import "../oracle/OracleModule.sol";
//todo
// import "../oracle/Oracle.sol";

import "../event/EventEmitter.sol";
import "../deposit/DepositVault.sol";
import "../feature/FeatureUtils.sol";

import "../deposit/DepositUtils.sol";

contract DepositHandler is
    IDepositHandler,
    GlobalReentrancyGuard,
    RoleModule,
    OracleModule
{
    // using Deposit for Deposit.Props;

    EventEmitter public immutable eventEmitter;
    DepositVault public immutable depositVault;

    // Oracle public immutable oracle;

    constructor(
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        DepositVault _depositVault
    )
        // Oracle _oracle
        RoleModule(_roleStore)
        GlobalReentrancyGuard(_dataStore)
    {
        eventEmitter = _eventEmitter;
        depositVault = _depositVault;
        // oracle = _oracle;
    }

    function createDeposit(
        address account,
        DepositUtils.CreateDepositParams calldata params
    ) external override globalNonReentrant onlyController returns (bytes32) {
        FeatureUtils.validateFeature(
            dataStore,
            Keys.createDepositFeatureDisabledKey(address(this))
        );
        return
            DepositUtils.createDeposit(
                dataStore,
                eventEmitter,
                depositVault,
                account,
                params
            );
    }
}
