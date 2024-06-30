// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./IExchangeRouter.sol";
import "../handler/IOrderHandler.sol";
import "../handler/IDepositHandler.sol";
import "../handler/IWithdrawalHandler.sol";

contract ExchangeRouter is IExchangeRouter {
    IDepositHandler public immutable depositHandler;
    IWithdrawalHandler public immutable withdrawalHandler;
    IOrderHandler public immutable orderHandler;

    constructor(
        IOrderHandler _orderHandler,
        IDepositHandler _depositHandler,
        IWithdrawalHandler _withdrawalHandler
    ) {
        orderHandler = _orderHandler;
        withdrawalHandler = _withdrawalHandler;
        depositHandler = _depositHandler;
    }

    function createDeposit(
        DepositHandler.CreateDepositParams calldata params
    ) external payable override returns (bytes32) {
        address account = msg.sender;
        return depositHandler.createDeposit(account, params);
    }

    function cancelDeposit(bytes32 key) external payable override {}

    function createWithdrawal(
        WithdrawalHandler.CreateWithdrawalParams calldata params
    ) external payable override returns (bytes32) {}

    function cancelWithdrawal(bytes32 key) external payable override {}

    function createOrder(
        Order.CreateOrderParams calldata params
    ) external payable returns (bytes32) {
        return orderHandler.createOrder(msg.sender, params);
    }
}
