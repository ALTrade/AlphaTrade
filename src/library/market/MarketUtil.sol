// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

library MarketUtil {
    bytes32 public constant MARKET_SALT = keccak256(abi.encode("MARKET_SALT"));

    function getMarketSaltHash(bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(MARKET_SALT, salt));
    }
}
