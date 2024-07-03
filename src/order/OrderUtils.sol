// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../data/DataStore.sol";
import "../event/EventEmitter.sol";
import "./OrderVault.sol";
import "../referral/IReferralStorage.sol";
import "./IBaseOrderUtils.sol";
import "../library/AccountUtils.sol";
import "../referral/ReferralUtils.sol";
import "../token/TokenUtils.sol";
import "./OrderStoreUtils.sol";
import "./OrderEventUtils.sol";
import "@openzeppelin/contracts/utils/Arrays.sol";
import "../callback/CallbackUtils.sol";
import "./BaseOrderUtils.sol";
import "../library/GasUtils.sol";
import "../library/NonceUtils.sol";
import "../market/MarketUtils.sol";

library OrderUtils {
    using Order for Order.Props;
    using Arrays for uint256[];

    // @dev creates an order in the order store
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param orderVault OrderVault
    // @param account the order account
    // @param params IBaseOrderUtils.CreateOrderParams
    function createOrder(
        DataStore dataStore,
        EventEmitter eventEmitter,
        OrderVault orderVault,
        IReferralStorage referralStorage,
        address account,
        IBaseOrderUtils.CreateOrderParams memory params
    ) external returns (bytes32) {
        AccountUtils.validateAccount(account);

        //TODO
        ReferralUtils.setTraderReferralCode(referralStorage, account, params.referralCode);

        uint256 initialCollateralDeltaAmount;

        address wnt = TokenUtils.wnt(dataStore);

        bool shouldRecordSeparateExecutionFeeTransfer = true;

        if (
            params.orderType == Order.OrderType.MarketSwap || params.orderType == Order.OrderType.LimitSwap
                || params.orderType == Order.OrderType.MarketIncrease || params.orderType == Order.OrderType.LimitIncrease
        ) {
            // for swaps and increase orders, the initialCollateralDeltaAmount is set based on the amount of tokens
            // transferred to the orderVault
            initialCollateralDeltaAmount = orderVault.recordTransferIn(params.addresses.initialCollateralToken);
            if (params.addresses.initialCollateralToken == wnt) {
                if (initialCollateralDeltaAmount < params.numbers.executionFee) {
                    revert Errors.InsufficientWntAmountForExecutionFee(
                        initialCollateralDeltaAmount, params.numbers.executionFee
                    );
                }
                initialCollateralDeltaAmount -= params.numbers.executionFee;
                shouldRecordSeparateExecutionFeeTransfer = false;
            }
        } else if (
            params.orderType == Order.OrderType.MarketDecrease || params.orderType == Order.OrderType.LimitDecrease
                || params.orderType == Order.OrderType.StopLossDecrease
        ) {
            initialCollateralDeltaAmount = params.numbers.initialCollateralDeltaAmount;
        } else {
            revert Errors.OrderTypeCannotBeCreated(uint256(params.orderType));
        }

        if (shouldRecordSeparateExecutionFeeTransfer) {
            uint256 wntAmount = orderVault.recordTransferIn(wnt);
            if (wntAmount < params.numbers.executionFee) {
                revert Errors.InsufficientWntAmountForExecutionFee(wntAmount, params.numbers.executionFee);
            }
            params.numbers.executionFee = wntAmount;
        }

        if (BaseOrderUtils.isPositionOrder(params.orderType)) {
            MarketUtils.validatePositionMarket(dataStore, params.addresses.market);
        }

        // validate swap path markets
        MarketUtils.validateSwapPath(dataStore, params.addresses.swapPath);

        Order.Props memory order;

        order.setAccount(account);
        order.setReceiver(params.addresses.receiver);
        order.setCallbackContract(params.addresses.callbackContract);
        order.setMarket(params.addresses.market);
        order.setInitialCollateralToken(params.addresses.initialCollateralToken);
        order.setUiFeeReceiver(params.addresses.uiFeeReceiver);
        order.setSwapPath(params.addresses.swapPath);
        order.setOrderType(params.orderType);
        order.setDecreasePositionSwapType(params.decreasePositionSwapType);
        order.setSizeDeltaUsd(params.numbers.sizeDeltaUsd);
        order.setInitialCollateralDeltaAmount(initialCollateralDeltaAmount);
        order.setTriggerPrice(params.numbers.triggerPrice);
        order.setAcceptablePrice(params.numbers.acceptablePrice);
        order.setExecutionFee(params.numbers.executionFee);
        order.setCallbackGasLimit(params.numbers.callbackGasLimit);
        order.setMinOutputAmount(params.numbers.minOutputAmount);
        order.setIsLong(params.isLong);
        order.setShouldUnwrapNativeToken(params.shouldUnwrapNativeToken);

        AccountUtils.validateReceiver(order.receiver());

        CallbackUtils.validateCallbackGasLimit(dataStore, order.callbackGasLimit());

        uint256 estimatedGasLimit = GasUtils.estimateExecuteOrderGasLimit(dataStore, order);
        GasUtils.validateExecutionFee(dataStore, estimatedGasLimit, order.executionFee());

        bytes32 key = NonceUtils.getNextKey(dataStore);

        order.touch();

        BaseOrderUtils.validateNonEmptyOrder(order);
        OrderStoreUtils.set(dataStore, key, order);

        OrderEventUtils.emitOrderCreated(eventEmitter, key, order);

        return key;
    }
}
