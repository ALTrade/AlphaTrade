// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../data/DataStore.sol";
import "../data/Keys.sol";

library FeatureUtils {
    function isFeatureDisabled(
        DataStore dataStore,
        bytes32 key
    ) internal view returns (bool) {
        return dataStore.getBool(key);
    }

    //check this feature is enabled or disabled
    function validateFeature(DataStore dataStore, bytes32 key) internal view {
        if (isFeatureDisabled(dataStore, key)) {
            revert Errors.DisabledFeature(key);
        }
    }
}
