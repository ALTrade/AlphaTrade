// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./IExchangeRouter.sol";

contract ExchangeRouter is IExchangeRouter {
    function createDeposit(
        DepositHandler.CreateDepositParams calldata params
    ) external payable override returns (bytes32) {}

    function cancelDeposit(bytes32 key) external payable override {}

    function createWithdrawal(
        WithdrawalHandler.CreateWithdrawalParams calldata params
    ) external payable override returns (bytes32) {}

    function cancelWithdrawal(bytes32 key) external payable override {}
}