// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../../data/DataStore.sol";
import "../../event/EventEmitter.sol";
import "./DepositVault.sol";
import "../market/MarketUtils.sol";
import "./Deposit.sol";
import "../chain/Chain.sol";

library DepositUtils {
    // @dev CreateDepositParams struct used in createDeposit to avoid stack
    // too deep errors
    //
    // @param receiver the address to send the market tokens to
    // @param callbackContract the callback contract
    // @param uiFeeReceiver the ui fee receiver
    // @param market the market to deposit into
    // @param minMarketTokens the minimum acceptable number of liquidity tokens
    // @param shouldUnwrapNativeToken whether to unwrap the native token when
    // sending funds back to the user in case the deposit gets cancelled
    // @param executionFee the execution fee for keepers
    // @param callbackGasLimit the gas limit for the callbackContract
    struct CreateDepositParams {
        address receiver;
        address callbackContract;
        address uiFeeReceiver;
        address market;
        address initialLongToken;
        address initialShortToken;
        address[] longTokenSwapPath;
        address[] shortTokenSwapPath;
        uint256 minMarketTokens;
        bool shouldUnwrapNativeToken;
        uint256 executionFee;
        uint256 callbackGasLimit;
    }

    function createDeposit(
        DataStore dataStore,
        EventEmitter eventEmitter,
        DepositVault depositVault,
        address account,
        CreateDepositParams memory params
    ) external returns (bytes32) {
        AccountUtils.validateAccount(account);
        Market.Props memory market = MarketUtils.getEnabledMarket(
            dataStore,
            params.market
        );
        MarketUtils.validateSwapPath(dataStore, params.longTokenSwapPath);
        MarketUtils.validateSwapPath(dataStore, params.shortTokenSwapPath);

        uint256 initialLongTokenAmount = depositVault.recordTransferIn(
            params.initialLongToken
        );
        uint256 initialShortTokenAmount = depositVault.recordTransferIn(
            params.initialShortToken
        );

        address wnt = TokenUtils.wnt(dataStore);

        if (params.initialLongToken == wnt) {
            initialLongTokenAmount -= params.executionFee;
        } else if (params.initialShortToken == wnt) {
            initialShortTokenAmount -= params.executionFee;
        } else {
            uint256 wntAmount = depositVault.recordTransferIn(wnt);
            if (wntAmount < params.executionFee) {
                revert Errors.InsufficientWntAmountForExecutionFee(
                    wntAmount,
                    params.executionFee
                );
            }
            params.executionFee = wntAmount;
        }

        if (initialLongTokenAmount == 0 && initialShortTokenAmount == 0) {
            revert Errors.EmptyDepositAmounts();
        }
        AccountUtils.validateReceiver(params.receiver);
        Deposit.Props memory deposit = Deposit.Props(
            Deposit.Address(
                account,
                params.receiver,
                params.callbackContract,
                params.uiFeeReceiver,
                market.marketToken,
                params.initialLongToken,
                params.initialShortToken,
                params.longTokenSwapPath,
                params.shortTokenSwapPath
            ),
            Deposit.Numbers(
                initialLongTokenAmount,
                initialShortTokenAmount,
                params.minMarketTokens,
                Chain.currentBlockNumber(),
                params.executionFee,
                params.callbackGasLimit
            ),
            Deposit.Flags(params.shouldUnwrapNativeToken)
        );

        CallbackUtils.validateCallbackGasLimit(
            dataStore,
            deposit.callbackGasLimit()
        );

        uint256 estimatedGasLimit = GasUtils.extimateExecuteDepositGasLimit(
            dataStore,
            deposit
        );
        GasUtils.validateExecutionFee(
            dataStore,
            estimatedGasLimit,
            params.executionFee
        );

        bytes32 key = NonceUtils.getNextKey(dataStore);
        DepositStoreUtils.set(dataStore, key, deposit);
        DepositStoreUtils.emitDepositCreated(eventEmitter, key, deposit);

        return key;
    }
}
