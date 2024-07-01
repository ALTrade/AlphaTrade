// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

import "../data/DataStore.sol";
import "../data/Keys.sol";
import "../error/ErrorUtils.sol";

library CallbackUtils {
    function validateCallbackGasLimit(DataStore dataStore, uint256 callbackGasLimit) internal view {
        uint256 maxCallbackGasLimit = dataStore.getUint(Keys.MAX_CALLBACK_GAS_LIMIT);
        if (callbackGasLimit > maxCallbackGasLimit) {
            revert Errors.MaxCallbackGasLimitExceeded(callbackGasLimit, maxCallbackGasLimit);
        }
    }
}
