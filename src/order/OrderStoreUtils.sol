// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./Order.sol";

import "../data/Keys.sol";
import "../data/DataStore.sol";

library OrderStoreUtils {
    using Order for Order.Props;

    bytes32 public constant ACCOUNT = keccak256(abi.encode("ACCOUNT"));
    bytes32 public constant RECEIVER = keccak256(abi.encode("RECEIVER"));
    bytes32 public constant CALLBACK_CONTRACT = keccak256(abi.encode("CALLBACK_CONTRACT"));
    bytes32 public constant UI_FEE_RECEIVER = keccak256(abi.encode("UI_FEE_RECEIVER"));
    bytes32 public constant MARKET = keccak256(abi.encode("MARKET"));
    bytes32 public constant INITIAL_COLLATERAL_TOKEN = keccak256(abi.encode("INITIAL_COLLATERAL_TOKEN"));
    bytes32 public constant SWAP_PATH = keccak256(abi.encode("SWAP_PATH"));

    bytes32 public constant ORDER_TYPE = keccak256(abi.encode("ORDER_TYPE"));
    bytes32 public constant DECREASE_POSITION_SWAP_TYPE = keccak256(abi.encode("DECREASE_POSITION_SWAP_TYPE"));
    bytes32 public constant SIZE_DELTA_USD = keccak256(abi.encode("SIZE_DELTA_USD"));
    bytes32 public constant INITIAL_COLLATERAL_DELTA_AMOUNT = keccak256(abi.encode("INITIAL_COLLATERAL_DELTA_AMOUNT"));
    bytes32 public constant TRIGGER_PRICE = keccak256(abi.encode("TRIGGER_PRICE"));
    bytes32 public constant ACCEPTABLE_PRICE = keccak256(abi.encode("ACCEPTABLE_PRICE"));
    bytes32 public constant EXECUTION_FEE = keccak256(abi.encode("EXECUTION_FEE"));
    bytes32 public constant CALLBACK_GAS_LIMIT = keccak256(abi.encode("CALLBACK_GAS_LIMIT"));
    bytes32 public constant MIN_OUTPUT_AMOUNT = keccak256(abi.encode("MIN_OUTPUT_AMOUNT"));
    bytes32 public constant UPDATED_AT_BLOCK = keccak256(abi.encode("UPDATED_AT_BLOCK"));

    bytes32 public constant IS_LONG = keccak256(abi.encode("IS_LONG"));
    bytes32 public constant SHOULD_UNWRAP_NATIVE_TOKEN = keccak256(abi.encode("SHOULD_UNWRAP_NATIVE_TOKEN"));
    bytes32 public constant IS_FROZEN = keccak256(abi.encode("IS_FROZEN"));

    function set(DataStore dataStore, bytes32 key, Order.Props memory order) external {
        dataStore.addBytes32(Keys.ORDER_LIST, key);

        dataStore.addBytes32(Keys.accountOrderListKey(order.account()), key);

        dataStore.setAddress(keccak256(abi.encode(key, ACCOUNT)), order.account());

        dataStore.setAddress(keccak256(abi.encode(key, RECEIVER)), order.receiver());

        dataStore.setAddress(keccak256(abi.encode(key, CALLBACK_CONTRACT)), order.callbackContract());

        dataStore.setAddress(keccak256(abi.encode(key, UI_FEE_RECEIVER)), order.uiFeeReceiver());

        dataStore.setAddress(keccak256(abi.encode(key, MARKET)), order.market());

        dataStore.setAddress(keccak256(abi.encode(key, INITIAL_COLLATERAL_TOKEN)), order.initialCollateralToken());

        dataStore.setAddressArray(keccak256(abi.encode(key, SWAP_PATH)), order.swapPath());

        dataStore.setUint(keccak256(abi.encode(key, ORDER_TYPE)), uint256(order.orderType()));

        dataStore.setUint(
            keccak256(abi.encode(key, DECREASE_POSITION_SWAP_TYPE)), uint256(order.decreasePositionSwapType())
        );

        dataStore.setUint(keccak256(abi.encode(key, SIZE_DELTA_USD)), order.sizeDeltaUsd());

        dataStore.setUint(
            keccak256(abi.encode(key, INITIAL_COLLATERAL_DELTA_AMOUNT)), order.initialCollateralDeltaAmount()
        );

        dataStore.setUint(keccak256(abi.encode(key, TRIGGER_PRICE)), order.triggerPrice());

        dataStore.setUint(keccak256(abi.encode(key, ACCEPTABLE_PRICE)), order.acceptablePrice());

        dataStore.setUint(keccak256(abi.encode(key, EXECUTION_FEE)), order.executionFee());

        dataStore.setUint(keccak256(abi.encode(key, CALLBACK_GAS_LIMIT)), order.callbackGasLimit());

        dataStore.setUint(keccak256(abi.encode(key, MIN_OUTPUT_AMOUNT)), order.minOutputAmount());

        dataStore.setUint(keccak256(abi.encode(key, UPDATED_AT_BLOCK)), order.updatedAtBlock());

        dataStore.setBool(keccak256(abi.encode(key, IS_LONG)), order.isLong());

        dataStore.setBool(keccak256(abi.encode(key, SHOULD_UNWRAP_NATIVE_TOKEN)), order.shouldUnwrapNativeToken());

        dataStore.setBool(keccak256(abi.encode(key, IS_FROZEN)), order.isFrozen());
    }
}
