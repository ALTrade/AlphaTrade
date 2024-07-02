// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../role/RoleModule.sol";
import "../data/DataStore.sol";
import "../event/EventEmitter.sol";

import "../library/AccountUtils.sol";
import "../token/TokenUtils.sol";

import "./Router.sol";

contract BaseRouter is RoleModule, ReentrancyGuard, PayableMulticall {
    Router public immutable router;
    DataStore public immutable dataStore;
    EventEmitter public immutable eventEmitter;

    constructor(Router _router, RoleStore _roleStore, DataStore _dataStore, EventEmitter _eventEmitter)
        RoleModule(_roleStore)
    {
        router = _router;
        dataStore = _dataStore;
        eventEmitter = _eventEmitter;
    }

    function sendWnt(address receiver, uint256 amount) external payable nonReentrant {
        AccountUtils.validateReceiver(receiver);
        TokenUtils.depositAndSendWrappedNativeToken(dataStore, receiver, amount);
    }

    function sendTokens(address token, address receiver, uint256 amount) external nonReentrant {
        AccountUtils.validateReceiver(receiver);
        router.pluginTransfer(token, msg.sender, receiver, amount);
    }

    function sendNativeToken(address receiver, uint256 amount) external payable nonReentrant {
        AccountUtils.validateReceiver(receiver);
        TokenUtils.sendNativeToken(dataStore, receiver, amount);
    }
}
