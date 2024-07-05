// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./Oracle.sol";

// @title OracleModule
// @dev Provides convenience functions for interacting with the Oracle
contract OracleModule {
    Oracle public immutable oracle;

    constructor(Oracle _oracle) {
        oracle = _oracle;
    }

    // @dev sets oracle prices, perform any additional tasks required,
    // and clear the oracle prices after
    //
    // care should be taken to avoid re-entrancy while using this call
    // since re-entrancy could allow functions to be called with prices
    // meant for a different type of transaction
    // the tokensWithPrices.length check in oracle.setPrices should help
    // mitigate this
    //
    // @param params OracleUtils.SetPricesParams
    modifier withOraclePrices(OracleUtils.SetPricesParams memory params) {
        oracle.setPrices(params);
        _;
        // todo
    }
}
