// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./IOrderHandler.sol";
import "../role/RoleModule.sol";
import "../library/GlobalReentrancyGuard.sol";
import "../library/FeatureUtils.sol";
import "../referral/IReferralStorage.sol";
import "../library/order/OrderUtils.sol";

contract OrderHandler is IOrderHandler, GlobalReentrancyGuard, RoleModule {
    IReferralStorage public immutable referralStorage;

    constructor(RoleStore _roleStore, DataStore _dataStore, IReferralStorage _referralStorage)
        RoleModule(_roleStore)
        GlobalReentrancyGuard(_dataStore)
    {
        referralStorage = _referralStorage;
    }

    // @dev creates an order in the order store
    // @param account the order's account
    // @param params BaseOrderUtils.CreateOrderParams
    function createOrder(address account, IBaseOrderUtils.CreateOrderParams calldata params)
        external
        override
        globalNonReentrant
        onlyController
        returns (bytes32)
    {
        FeatureUtils.validateFeature(
            dataStore, Keys.createOrderFeatureDisabledKey(address(this), uint256(params.orderType))
        );

        return OrderUtils.createOrder(dataStore, eventEmitter, orderVault, referralStorage, account, params);
    }
}
