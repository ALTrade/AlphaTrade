// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../library/market/Market.sol";
import "../library/market/MarketUtil.sol";
import "../data/DataStore.sol";
import "./MarketToken.sol";
import "../error/Errors.sol";

contract MarketFactory {
    DataStore public immutable dataStore;

    constructor(DataStore _dataStore) {
        dataStore = _dataStore;
    }

    function createMarket(
        address indexToken,
        address longToken,
        address shortToken,
        bytes32 marketType
    ) external returns (Market.Props memory) {
        bytes32 salt = keccak256(
            abi.encode(
                "Alpha_Trade",
                indexToken,
                longToken,
                shortToken,
                marketType
            )
        );

        address existingMarketAddress = dataStore.getAddress(
            MarketUtil.getMarketSaltHash(salt)
        );
        if (existingMarketAddress != address(0)) {
            revert Errors.MarketAlreadyExists(salt, existingMarketAddress);
        }

        MarketToken marketToken = new MarketToken{salt: salt}(
            roleStore,
            dataStore
        );

        // the marketType is not stored with the market, it is mainly used to ensure
        // markets with the same indexToken, longToken and shortToken can be created if needed
        Market.Props memory market = Market.Props(
            address(marketToken),
            indexToken,
            longToken,
            shortToken
        );

        MarketStoreUtils.set(dataStore, address(marketToken), salt, market);

        emitMarketCreated(
            address(marketToken),
            salt,
            indexToken,
            longToken,
            shortToken
        );

        return market;
    }

    function emitMarketCreated(
        address marketToken,
        bytes32 salt,
        address indexToken,
        address longToken,
        address shortToken
    ) internal {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(4);
        eventData.addressItems.setItem(0, "marketToken", marketToken);
        eventData.addressItems.setItem(1, "indexToken", indexToken);
        eventData.addressItems.setItem(2, "longToken", longToken);
        eventData.addressItems.setItem(3, "shortToken", shortToken);

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "salt", salt);

        eventEmitter.emitEventLog1(
            "MarketCreated",
            Cast.toBytes32(marketToken),
            eventData
        );
    }
}
