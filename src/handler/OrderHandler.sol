// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./BaseOrderHandler.sol";
import "../error/ErrorUtils.sol";
import "./IOrderHandler.sol";
import "../library/FeatureUtils.sol";
import "../order/OrderUtils.sol";
import "../oracle/OracleUtils.sol";

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
        //记录了最初的gas
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

    /**
     * @dev Updates the given order with the specified size delta, acceptable price, and trigger price.
     * The `updateOrder()` feature must be enabled for the given order type. The caller must be the owner
     * of the order, and the order must not be a market order. The size delta, trigger price, and
     * acceptable price are updated on the order, and the order is unfrozen. Any additional WNT that is
     * transferred to the contract is added to the order's execution fee. The updated order is then saved
     * in the order store, and an `OrderUpdated` event is emitted.
     *
     * A user may be able to observe exchange prices and prevent order execution by updating the order's
     * trigger price or acceptable price
     *
     * The main front-running concern is if a user knows whether the price is going to move up or down
     * then positions accordingly, e.g. if price is going to move up then the user opens a long position
     *
     * With updating of orders, a user may know that price could be lower and delays the execution of an
     * order by updating it, this should not be a significant front-running concern since it is similar
     * to observing prices then creating a market order as price is decreasing
     *
     * @param key The unique ID of the order to be updated
     * @param sizeDeltaUsd The new size delta for the order
     * @param acceptablePrice The new acceptable price for the order
     * @param triggerPrice The new trigger price for the order
     */
    function updateOrder(
        bytes32 key,
        uint256 sizeDeltaUsd,
        uint256 acceptablePrice,
        uint256 triggerPrice,
        uint256 minOutputAmount,
        Order.Props memory order
    ) external override globalNonReentrant onlyController {
        FeatureUtils.validateFeature(
            dataStore, Keys.updateOrderFeatureDisabledKey(address(this), uint256(order.orderType()))
        );

        if (BaseOrderUtils.isMarketOrder(order.orderType())) {
            revert Errors.OrderNotUpdatable(uint256(order.orderType()));
        }

        order.setSizeDeltaUsd(sizeDeltaUsd);
        order.setTriggerPrice(triggerPrice);
        order.setAcceptablePrice(acceptablePrice);
        order.setMinOutputAmount(minOutputAmount);
        order.setIsFrozen(false);

        // allow topping up of executionFee as frozen orders
        // will have their executionFee reduced
        address wnt = TokenUtils.wnt(dataStore);
        uint256 receivedWnt = orderVault.recordTransferIn(wnt);
        order.setExecutionFee(order.executionFee() + receivedWnt);

        uint256 estimatedGasLimit = GasUtils.estimateExecuteOrderGasLimit(dataStore, order);
        GasUtils.validateExecutionFee(dataStore, estimatedGasLimit, order.executionFee());

        order.touch();

        BaseOrderUtils.validateNonEmptyOrder(order);

        OrderStoreUtils.set(dataStore, key, order);

        OrderEventUtils.emitOrderUpdated(
            eventEmitter, key, order.account(), sizeDeltaUsd, acceptablePrice, triggerPrice, minOutputAmount
        );
    }

    function executeOrder(bytes32 key, OracleUtils.SetPricesParams calldata oracleParams)
        external
        globalNonReentrant
        onlyOrderKeeper
        withOraclePrices
    {}
}
