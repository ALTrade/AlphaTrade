// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../order/IBaseOrderUtils.sol";

interface IOrderHandler {
    function createOrder(
        address account,
        IBaseOrderUtils.CreateOrderParams calldata params
    ) external returns (bytes32);
}
