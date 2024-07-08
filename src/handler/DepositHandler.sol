// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./IDepositHandler.sol";
import "../library/GlobalReentrancyGuard.sol";
import "../role/RoleModule.sol";
import "../oracle/OracleModule.sol";
import "../oracle/Oracle.sol";
import "../oracle/OracleUtils.sol";

import "../event/EventEmitter.sol";
import "../deposit/DepositVault.sol";
import "../library/FeatureUtils.sol";

import "../deposit/DepositUtils.sol";
import "../library/ExchangeUtils.sol";
import "../deposit/DepositStoreUtils.sol";

contract DepositHandler is IDepositHandler, GlobalReentrancyGuard, RoleModule, OracleModule {
    using Deposit for Deposit.Props;

    EventEmitter public immutable eventEmitter;
    DepositVault public immutable depositVault;

    constructor(
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        Oracle _oracle,
        DepositVault _depositVault
    ) GlobalReentrancyGuard(_dataStore) RoleModule(_roleStore) OracleModule(_oracle) {
        eventEmitter = _eventEmitter;
        depositVault = _depositVault;
        oracle = _oracle;
    }

    function createDeposit(address account, DepositUtils.CreateDepositParams calldata params)
        external
        override
        globalNonReentrant
        onlyController
        returns (bytes32)
    {
        FeatureUtils.validateFeature(dataStore, Keys.createDepositFeatureDisabledKey(address(this)));
        return DepositUtils.createDeposit(dataStore, eventEmitter, depositVault, account, params);
    }

    function cancelDeposit(bytes32 key) external override globalNonReentrant onlyController {
        uint256 startingGas = gasleft();

        DataStore _dataStore = dataStore;
        Deposit.Props memory deposit = DepositStoreUtils.get(_dataStore, key);
        FeatureUtils.validateFeature(_dataStore, Keys.cancelDepositFeatureDisabledKey(address(this)));

        ExchangeUtils.validateRequestCancellation(_dataStore, deposit.updatedAtBlock(), "Deposit");

        DepositUtils.cancelDeposit(
            _dataStore, eventEmitter, depositVault, key, deposit.account(), startingGas, Keys.USER_INITIATED_CANCEL, ""
        );
    }

    function executeDeposit(bytes32 key, OracleUtils.SetPricesParams calldata oracleParams)
        external
        globalNonReentrant
        onlyOrderKeeper
        withOraclePrices(oracleParams)
    {
        uint256 startingGas = gasleft();
        Deposit.Props memory deposit = DepositStoreUtils.get(dataStore, key);
        uint256 estimatedGasLimit = GasUtils.estimateExecuteDepositGasLimit(dataStore, deposit);
        GasUtils.validateExecutionGas(dataStore, startingGas, estimatedGasLimit);

        uint256 executionGas = GasUtils.getExecutionGas(dataStore, startingGas);
        try this._executeDeposit{gas: executionGas}(key, deposit, msg.sender) {}
        catch (bytes memory reasonBytes) {
            _handleDepositError(key, startingGas, reasonBytes);
        }
    }

    function simulateExecuteDeposit(bytes32 key, OracleUtils.SimulatePricesParams memory params)
        external
        override
        onlyController
        withSimulatedOraclePrices(oracle, params)
        globalNonReentrant
    {
        //todo  这个没有初始化
        OracleUtils.SetPricesParams memory oracleParams;
        Deposit.Props memory deposit = DepositStoreUtils.get(dataStore, key);
        this._executeDeposit(key, deposit, oracleParams, msg.sender);
    }

    function _executeDeposit(bytes32 key, Deposit.Props memory deposit, address keeper) external onlySelf {
        uint256 startingGas = gasleft();

        FeatureUtils.validateFeature(dataStore, Keys.executeDepositFeatureDisabledKey(address(this)));

        // ExecuteDepositUtils.ExecuteDepositParams memory params = ExecuteDepositUtils.ExecuteDepositParams(
        //     dataStore,
        //     eventEmitter,
        //     depositVault,
        //     oracle,
        //     key,
        //     keeper,
        //     startingGas,
        //     ISwapPricingUtils.SwapPricingType.TwoStep,
        //     true // includeVirtualInventoryImpact
        // );

        // ExecuteDepositUtils.executeDeposit(params, deposit);
    }

    function _handleDepositError(bytes32 key, uint256 startingGas, bytes memory reasonBytes) internal {
        GasUtils.validateExecutionErrorGas(dataStore, reasonBytes);
    }
}
