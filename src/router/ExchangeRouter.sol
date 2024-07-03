// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./IExchangeRouter.sol";
import "../handler/IDepositHandler.sol";
import "../handler/IWithdrawalHandler.sol";
import "../handler/IOrderHandler.sol";
import "./BaseRouter.sol";
import "../order/OrderStoreUtils.sol";

contract ExchangeRouter is IExchangeRouter, BaseRouter {
    IDepositHandler public immutable depositHandler;
    IWithdrawalHandler public immutable withdrawalHandler;
    IOrderHandler public immutable orderHandler;

    constructor(
        Router _router,
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        IOrderHandler _orderHandler,
        IDepositHandler _depositHandler,
        IWithdrawalHandler _withdrawalHandler
    ) BaseRouter(_router, _roleStore, _dataStore, _eventEmitter) {
        orderHandler = _orderHandler;
        withdrawalHandler = _withdrawalHandler;
        depositHandler = _depositHandler;
    }

    function createDeposit(DepositHandler.CreateDepositParams calldata params)
        external
        payable
        override
        returns (bytes32)
    {
        address account = msg.sender;
        return depositHandler.createDeposit(account, params);
    }

    function cancelDeposit(bytes32 key) external payable override {
        Deposit.Props memory deposit = DepositUtils.get(DataStore, key);
        if (deposit.account() == address(0)) {
            revert Errors.EmptyDeposit();
        }

        if (deposit.account() != msg.sender) {
            revert Errors.Unauthorized(msg.sender, "account for cancelDeposit");
        }

        depositHandler.cancelDeposit(key);
    }

    function createWithdrawal(WithdrawalHandler.CreateWithdrawalParams calldata params)
        external
        payable
        override
        returns (bytes32)
    {}

    function cancelWithdrawal(bytes32 key) external payable override {}

    function createOrder(Order.CreateOrderParams calldata params) external payable returns (bytes32) {
        return orderHandler.createOrder(msg.sender, params);
    }

    function cancelOrder(bytes32 key) external payable nonReentrant {
        Order.Props memory order = OrderStoreUtils.get(dataStore, key);
        if (order.account() == address(0)) {
            revert Errors.EmptyOrder();
        }

        if (order.account() != msg.sender) {
            revert Errors.Unauthorized(msg.sender, "account for cancelOrder");
        }

        orderHandler.cancelOrder(key);
    }
}
