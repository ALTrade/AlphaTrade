// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./BaseHandler.sol";
import "./IWithdrawalHandler.sol";
import "../library/GlobalReentrancyGuard.sol";
import "../role/RoleModule.sol";
import "../oracle/Oracle.sol";
import "../oracle/OracleModule.sol";
import "../event/EventEmitter.sol";
import "../withdrawal/WithdrawalVault.sol";
import "../withdrawal/WithdrawalStoreUtils.sol";
import "../withdrawal/ExecuteWithdrawalUtils.sol";
import "../library/FeatureUtils.sol";
import "../library/ExchangeUtils.sol";

contract WithdrawalHandler is IWithdrawalHandler, BaseHandler {
    using Withdrawal for Withdrawal.Props;

    WithdrawalVault public immutable withdrawalVault;

    constructor(
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        Oracle _oracle,
        WithdrawalVault _withdrawalVault
    ) BaseHandler(_roleStore, _dataStore, _eventEmitter, _oracle) {
        withdrawalVault = _withdrawalVault;
    }

    // @dev creates a withdrawal in the withdrawal store
    // @param account the withdrawing account
    // @param params WithdrawalUtils.CreateWithdrawalParams
    function createWithdrawal(address account, WithdrawalUtils.CreateWithdrawalParams calldata params)
        external
        override
        globalNonReentrant
        onlyController
        returns (bytes32)
    {
        FeatureUtils.validateFeature(dataStore, Keys.createWithdrawalFeatureDisabledKey(address(this)));

        return WithdrawalUtils.createWithdrawal(dataStore, eventEmitter, withdrawalVault, account, params);
    }

    // @dev cancels a withdrawal
    // @param key the withdrawal key
    function cancelWithdrawal(bytes32 key) external override globalNonReentrant onlyController {
        uint256 startingGas = gasleft();

        DataStore _dataStore = dataStore;
        Withdrawal.Props memory withdrawal = WithdrawalStoreUtils.get(_dataStore, key);

        FeatureUtils.validateFeature(_dataStore, Keys.cancelWithdrawalFeatureDisabledKey(address(this)));

        ExchangeUtils.validateRequestCancellation(_dataStore, withdrawal.updatedAtBlock(), "Withdrawal");

        WithdrawalUtils.cancelWithdrawal(
            _dataStore,
            eventEmitter,
            withdrawalVault,
            key,
            withdrawal.account(),
            startingGas,
            Keys.USER_INITIATED_CANCEL,
            ""
        );
    }

    // @dev executes a withdrawal
    // @param key the key of the withdrawal to execute
    // @param oracleParams OracleUtils.SetPricesParams
    function executeWithdrawal(bytes32 key, OracleUtils.SetPricesParams calldata oracleParams)
        external
        globalNonReentrant
        onlyOrderKeeper
        withOraclePrices(oracleParams)
    {
        uint256 startingGas = gasleft();

        oracle.validateSequencerUp();

        Withdrawal.Props memory withdrawal = WithdrawalStoreUtils.get(dataStore, key);
        uint256 estimatedGasLimit = GasUtils.estimateExecuteWithdrawalGasLimit(dataStore, withdrawal);
        GasUtils.validateExecutionGas(dataStore, startingGas, estimatedGasLimit);

        uint256 executionGas = GasUtils.getExecutionGas(dataStore, startingGas);

        try this._executeWithdrawal{gas: executionGas}(
            key, withdrawal, msg.sender, ISwapPricingUtils.SwapPricingType.TwoStep
        ) {} catch (bytes memory reasonBytes) {
            _handleWithdrawalError(key, startingGas, reasonBytes);
        }
    }

    function _handleWithdrawalError(bytes32 key, uint256 startingGas, bytes memory reasonBytes) internal {
        GasUtils.validateExecutionErrorGas(dataStore, reasonBytes);

        bytes4 errorSelector = ErrorUtils.getErrorSelectorFromData(reasonBytes);

        validateNonKeeperError(errorSelector, reasonBytes);

        (string memory reason, /* bool hasRevertMessage */ ) = ErrorUtils.getRevertMessage(reasonBytes);

        WithdrawalUtils.cancelWithdrawal(
            dataStore, eventEmitter, withdrawalVault, key, msg.sender, startingGas, reason, reasonBytes
        );
    }

    // @dev executes a withdrawal
    // @param oracleParams OracleUtils.SetPricesParams
    // @param keeper the keeper executing the withdrawal
    // @param startingGas the starting gas
    function _executeWithdrawal(
        bytes32 key,
        Withdrawal.Props memory withdrawal,
        address keeper,
        ISwapPricingUtils.SwapPricingType swapPricingType
    ) external onlySelf {
        uint256 startingGas = gasleft();

        FeatureUtils.validateFeature(dataStore, Keys.executeWithdrawalFeatureDisabledKey(address(this)));

        ExecuteWithdrawalUtils.ExecuteWithdrawalParams memory params = ExecuteWithdrawalUtils.ExecuteWithdrawalParams(
            dataStore, eventEmitter, withdrawalVault, oracle, key, keeper, startingGas, swapPricingType
        );

        ExecuteWithdrawalUtils.executeWithdrawal(params, withdrawal);
    }
}
