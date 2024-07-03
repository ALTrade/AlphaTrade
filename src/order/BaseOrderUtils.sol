// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./Order.sol";
import "../error/Errors.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

library BaseOrderUtils {
    using SafeCast for int256;
    using SafeCast for uint256;

    using Order for Order.Props;
    // @dev check if an orderType is a position order
    // @param orderType the order type
    // @return whether an orderType is a position order

    function isPositionOrder(Order.OrderType orderType) internal pure returns (bool) {
        return isIncreaseOrder(orderType) || isDecreaseOrder(orderType);
    }

    // @dev check if an orderType is an increase order
    // @param orderType the order type
    // @return whether an orderType is an increase order
    function isIncreaseOrder(Order.OrderType orderType) internal pure returns (bool) {
        return orderType == Order.OrderType.MarketIncrease || orderType == Order.OrderType.LimitIncrease;
    }

    // @dev check if an orderType is a decrease order
    // @param orderType the order type
    // @return whether an orderType is a decrease order
    function isDecreaseOrder(Order.OrderType orderType) internal pure returns (bool) {
        return orderType == Order.OrderType.MarketDecrease || orderType == Order.OrderType.LimitDecrease
            || orderType == Order.OrderType.StopLossDecrease || orderType == Order.OrderType.Liquidation;
    }

    // @dev validate that an order exists
    // @param order the order to check
    function validateNonEmptyOrder(Order.Props memory order) internal pure {
        if (order.account() == address(0)) {
            revert Errors.EmptyOrder();
        }

        if (order.sizeDeltaUsd() == 0 && order.initialCollateralDeltaAmount() == 0) {
            revert Errors.EmptyOrder();
        }
    }

    // @dev check if an orderType is a swap order
    // @param orderType the order type
    // @return whether an orderType is a swap order
    function isSwapOrder(Order.OrderType orderType) internal pure returns (bool) {
        return orderType == Order.OrderType.MarketSwap || orderType == Order.OrderType.LimitSwap;
    }

    // @dev check if an orderType is a market order
    // @param orderType the order type
    // @return whether an orderType is a market order
    function isMarketOrder(Order.OrderType orderType) internal pure returns (bool) {
        // a liquidation order is not considered as a market order
        return orderType == Order.OrderType.MarketSwap || orderType == Order.OrderType.MarketIncrease
            || orderType == Order.OrderType.MarketDecrease;
    }
}
