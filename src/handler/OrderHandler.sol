// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./BaseOrderHandler.sol";
import "../error/ErrorUtils.sol";
import "./IOrderHandler.sol";
import "../library/FeatureUtils.sol";
import "../order/OrderUtils.sol";

contract OrderHandler is IOrderHandler, BaseOrderHandler {
    using SafeCast for uint256;
    using Order for Order.Props;
    using Array for uint256[];

    // todo oracle swapHandler
    constructor(
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventRmitter,
        OrderVault _orderVault,
        IReferralStorage _referralStorage
    ) BaseOrderHandler(_roleStore, _dataStore, _eventRmitter, _orderVault, _referralStorage) {}

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

    /**
     * @dev Cancels the given order. The `cancelOrder()` feature must be enabled for the given order
     * type. The caller must be the owner of the order. The order is cancelled by calling the `cancelOrder()`
     * function in the `OrderUtils` contract. This function also records the starting gas amount and the
     * reason for cancellation, which is passed to the `cancelOrder()` function.
     *
     * @param key The unique ID of the order to be cancelled
     */
    function cancelOrder(bytes32 key) external payable globalNonReentrant onlyController {
        uint256 startingGas = gasleft();

        DataStore _dataStore = dataStore;
        Order.Props memory order = OrderStoreUtils.get(_dataStore, key);

        FeatureUtils.validateFeature(
            dataStore, Keys.cancelOrderFeatureDisabledKey(address(this), uint256(params.orderType))
        );

        if (BaseOrderHandler.isMarketOrder(order.orderType())) {
            ExchangeUtils.validateRequestCancellation(_dataStore, order.updatedAtBlock(), "Order");
        }
        OrderUtils.cancelOrder(
            dataStore, eventEmitter, orderVault, key, order.account(), startingGas, Keys.USER_INITIATED_CANCEL, ""
        );
    }
}
