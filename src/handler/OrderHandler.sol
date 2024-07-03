// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./IOrderHandler.sol";
import "../role/RoleModule.sol";
import "../library/GlobalReentrancyGuard.sol";
import "../library/FeatureUtils.sol";
import "../referral/IReferralStorage.sol";
import "../order/OrderUtils.sol";
import "../event/EventEmitter.sol";
import "./BaseOrderHandler.sol";

contract OrderHandler is IOrderHandler, BaseOrderHandler {
    using SafeCast for uint256;
    using Order for Order.Props;
    using Array for uint256[];

    constructor(
        RoleStore _roleStore,
        DataStore _dataStore,
        IReferralStorage _referralStorage,
        OrderVault _orderVault,
        EventEmitter _eventEmitter
    ) BaseOrderHandler(_roleStore, _dataStore, _eventEmitter, _orderVault, _referralStorage) {}

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
