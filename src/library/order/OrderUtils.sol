// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../../data/DataStore.sol";
import "../../event/EventEmitter.sol";
import "./OrderVault.sol";
import "../../referral/IReferralStorage.sol";
import "./IBaseOrderUtils.sol";
import "../AccountUtils.sol";
import "../../referral/ReferralUtils.sol";
import "../../token/TokenUtils.sol";

library OrderUtils {
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
        ReferralUtils.setTraderReferralCode(
            referralStorage,
            account,
            params.referralCode
        );

        uint256 initialCollateralDeltaAmount;

        address wnt = TokenUtils.wnt(dataStore);

        bool shouldRecordSeparateExecutionFeeTransfer = true;

        if (
            params.orderType == Order.OrderType.MarketSwap ||
            params.orderType == Order.OrderType.LimitSwap ||
            params.orderType == Order.OrderType.MarketIncrease ||
            params.orderType == Order.OrderType.LimitIncrease
        ) {
            // for swaps and increase orders, the initialCollateralDeltaAmount is set based on the amount of tokens
            // transferred to the orderVault
            orderVault.recordTransferIn(
                params.addresses.initialCollateralToken
            );
        }
    }
}
