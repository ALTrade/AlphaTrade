// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../handler/DepositHandler.sol";
import "../handler/WithdrawalHandler.sol";

interface IExchangeRouter {

    function createDeposit(DepositHandler.CreateDepositParams calldata params) external payable returns(bytes32);
    
    function cancelDeposit(bytes32 key) external payable;

    function createWithdrawal(WithdrawalHandler.CreateWithdrawalParams calldata params) external payable returns(bytes32);

    function cancelWithdrawal(bytes32 key) external payable;

}