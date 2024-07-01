// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../library/deposit/DepositUtils.sol";

interface IDepositHandler {
    function createDeposit(
        address account,
        DepositUtils.CreateDepositParams calldata params
    ) external returns (bytes32);
}
