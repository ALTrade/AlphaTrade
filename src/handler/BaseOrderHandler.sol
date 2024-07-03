// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../library/GlobalReentrancyGuard.sol";
import "../role/RoleModule.sol";
import "../oracle/OracleModule.sol";
import "../order/Order.sol";
import "../event/EventEmitter.sol";
import "../order/OrderVault.sol";
import "../referral/IReferralStorage.sol";
import "../library/Array.sol";

contract BaseOrderHandler is GlobalReentrancyGuard, RoleModule, OracleModule {
    using SafeCast for uint256;
    using Order for Order.Props;
    using Array for uint256[];

    EventEmitter public immutable eventEmitter;
    OrderVault public immutable orderVault;
    IReferralStorage public immutable referralStorage;

    constructor(
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        OrderVault _orderVault,
        IReferralStorage _referralStorage
    ) RoleModule(_roleStore) GlobalReentrancyGuard(_dataStore) {
        eventEmitter = _eventEmitter;
        orderVault = _orderVault;
        referralStorage = _referralStorage;
    }
}
