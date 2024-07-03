// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../../data/DataStore.sol";
import "./Market.sol";
import "./MarketStoreUtils.sol";

library MarketUtils {
    bytes32 public constant MARKET_SALT = keccak256(abi.encode("MARKET_SALT"));

    function getMarketSaltHash(bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(MARKET_SALT, salt));
    }

    function getEnabledMarket(DataStore dataStore, address marketAddress) internal view returns (Market.Props memory) {
        Market.Props memory market = MarketStoreUtils.get(dataStore, marketAddress);
        validateEnabledMarket(dataStore, market);
        return market;
    }

    function validateEnabledMarket(DataStore dataStore, address marketAddress) internal view {
        Market.Props memory market = MarketStoreUtils.get(dataStore, marketAddress);
        validateEnabledMarket(dataStore, market);
    }

    function validateEnabledMarket(DataStore dataStore, Market.Props memory market) internal view {
        if (market.marketToken == address(0)) {
            revert Errors.EmptyMarket();
        }

        bool isMarketDisabled = dataStore.getBool(Keys.isMarketDisabledKey(market.marketToken));
        if (isMarketDisabled) {
            revert Errors.DisabledMarket(market.marketToken);
        }
    }

    function validateSwapPath(DataStore dataStore, address[] memory swapPath) internal view {
        uint256 maxSwapPathLength = dataStore.getUint(Keys.MAX_SWAP_PATH_LENGTH);
        if (swapPath.length > maxSwapPathLength) {
            revert Errors.MaxSwapPathLengthExceeded(swapPath.length, maxSwapPathLength);
        }

        for (uint256 i; i < swapPath.length; i++) {
            address marketAddress = swapPath[i];
            validateSwapMarket(dataStore, marketAddress);
        }
    }

    function validateSwapMarket(DataStore dataStore, address marketAddress) internal view {
        Market.Props memory market = MarketStoreUtils.get(dataStore, marketAddress);
        validateSwapMarket(dataStore, market);
    }

    function validateSwapMarket(DataStore dataStore, Market.Props memory market) internal view {
        validateEnabledMarket(dataStore, market);

        if (market.longToken == market.shortToken) {
            revert Errors.InvalidSwapMarket(market.marketToken);
        }
    }

    // @dev validate that the positions can be opened in the given market
    // @param market the market to check
    function validatePositionMarket(DataStore dataStore, Market.Props memory market) internal view {
        validateEnabledMarket(dataStore, market);

        if (isSwapOnlyMarket(market)) {
            revert Errors.InvalidPositionMarket(market.marketToken);
        }
    }

    // @dev check if a market only supports swaps and not positions
    // @param market the market to check
    function isSwapOnlyMarket(Market.Props memory market) internal pure returns (bool) {
        return market.indexToken == address(0);
    }
}
