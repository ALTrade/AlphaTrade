// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../data/DataStore.sol";
import "../event/EventEmitter.sol";
import "../oracle/Oracle.sol";
import "../pricing/SwapPricingUtils.sol";
import "../fee/FeeUtils.sol";

/**
 * @title SwapUtils
 * @dev Library for swap functions
 */
library SwapUtils {
    using SafeCast for uint256;
    using SafeCast for int256;
    using Price for Price.Props;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    /**
     * @param dataStore The contract that provides access to data stored on-chain.
     * @param eventEmitter The contract that emits events.
     * @param oracle The contract that provides access to price data from oracles.
     * @param bank The contract providing the funds for the swap.
     * @param key An identifying key for the swap.
     * @param tokenIn The address of the token that is being swapped.
     * @param amountIn The amount of the token that is being swapped.
     * @param swapPathMarkets An array of market properties, specifying the markets in which the swap should be executed.
     * @param minOutputAmount The minimum amount of tokens that should be received as part of the swap.
     * @param receiver The address to which the swapped tokens should be sent.
     * @param uiFeeReceiver The address of the ui fee receiver.
     * @param shouldUnwrapNativeToken A boolean indicating whether the received tokens should be unwrapped from the wrapped native token (WNT) if they are wrapped.
     */
    struct SwapParams {
        DataStore dataStore;
        EventEmitter eventEmitter;
        Oracle oracle;
        Bank bank;
        bytes32 key;
        address tokenIn;
        uint256 amountIn;
        Market.Props[] swapPathMarkets;
        uint256 minOutputAmount;
        address receiver;
        address uiFeeReceiver;
        bool shouldUnwrapNativeToken;
    }

    /**
     * @param market The market in which the swap should be executed.
     * @param tokenIn The address of the token that is being swapped.
     * @param amountIn The amount of the token that is being swapped.
     * @param receiver The address to which the swapped tokens should be sent.
     * @param shouldUnwrapNativeToken A boolean indicating whether the received tokens should be unwrapped from the wrapped native token (WNT) if they are wrapped.
     */
    struct _SwapParams {
        Market.Props market;
        address tokenIn;
        uint256 amountIn;
        address receiver;
        bool shouldUnwrapNativeToken;
    }

    /**
     * @param tokenOut The address of the token that is being received as part of the swap.
     * @param tokenInPrice The price of the token that is being swapped.
     * @param tokenOutPrice The price of the token that is being received as part of the swap.
     * @param amountIn The amount of the token that is being swapped.
     * @param amountOut The amount of the token that is being received as part of the swap.
     * @param poolAmountOut The total amount of the token that is being received by all users in the swap pool.
     */
    struct SwapCache {
        address tokenOut;
        Price.Props tokenInPrice;
        Price.Props tokenOutPrice;
        uint256 amountIn;
        uint256 amountInAfterFees;
        uint256 amountOut;
        uint256 poolAmountOut;
        int256 priceImpactUsd;
        int256 priceImpactAmount;
        uint256 cappedDiffUsd;
        int256 tokenInPriceImpactAmount;
    }

    event SwapReverted(string reason, bytes reasonBytes);

    /**
     * @dev Swaps a given amount of a given token for another token based on a
     * specified swap path.
     * @param params The parameters for the swap.
     * @return A tuple containing the address of the token that was received as
     * part of the swap and the amount of the received token.
     */
    function swap(SwapParams memory params) external returns (address, uint256) {
        if (params.amountIn == 0) {
            return (params.tokenIn, params.amountIn);
        }

        //如果交换路径为0，那么意味着这是一次转账操作
        if (params.swapPathMarkets.length == 0) {
            //转账操作，输出金额不能大于输入金额
            if (params.amountIn < params.minOutputAmount) {
                revert Errors.InsufficientOutputAmount(params.amountIn, params.minOutputAmount);
            }
            //地址不能是vault的地址，才能转账
            if (address(params.bank) != params.receiver) {
                params.bank.transferOut(
                    params.tokenIn, params.receiver, params.amountIn, params.shouldUnwrapNativeToken
                );
            }

            return (params.tokenIn, params.amountIn);
        }
        //先把钱从vault转给交换路径中第一个market
        if (address(params.bank) != params.swapPathMarkets[0].marketToken) {
            params.bank.transferOut(params.tokenIn, params.swapPathMarkets[0].marketToken, params.amountIn, false);
        }

        address tokenOut = params.tokenIn;
        uint256 outputAmount = params.amountIn;
        //开始循环执行
        for (uint256 i; i < params.swapPathMarkets.length; i++) {
            Market.Props memory market = params.swapPathMarkets[i];

            bool flagExists = params.dataStore.getBool(Keys.swapPathMarketFlagKey(market.marketToken));
            if (flagExists) {
                revert Errors.DuplicatedMarketInSwapPath(market.marketToken);
            }
            //给执行过交换的市场设置一个标志，防止路径中出现重复的market
            params.dataStore.setBool(Keys.swapPathMarketFlagKey(market.marketToken), true);

            uint256 nextIndex = i + 1;
            address receiver;
            //如果没有下一个市场了，就要把钱转给用户设置的receiver
            if (nextIndex < params.swapPathMarkets.length) {
                receiver = params.swapPathMarkets[nextIndex].marketToken;
            } else {
                receiver = params.receiver;
            }

            _SwapParams memory _params = _SwapParams(
                market,
                tokenOut,
                outputAmount,
                receiver,
                i == params.swapPathMarkets.length - 1 ? params.shouldUnwrapNativeToken : false // only convert ETH on the last swap if needed
            );

            (tokenOut, outputAmount) = _swap(params, _params);
        }

        for (uint256 i; i < params.swapPathMarkets.length; i++) {
            Market.Props memory market = params.swapPathMarkets[i];
            params.dataStore.setBool(Keys.swapPathMarketFlagKey(market.marketToken), false);
        }

        if (outputAmount < params.minOutputAmount) {
            revert Errors.InsufficientSwapOutputAmount(outputAmount, params.minOutputAmount);
        }

        return (tokenOut, outputAmount);
    }

    function validateSwapOutputToken(
        DataStore dataStore,
        address[] memory swapPath,
        address inputToken,
        address expectedOutputToken
    ) internal view {
        address outputToken = getOutputToken(dataStore, swapPath, inputToken);
        if (outputToken != expectedOutputToken) {
            revert Errors.InvalidSwapOutputToken(outputToken, expectedOutputToken);
        }
    }

    function getOutputToken(DataStore dataStore, address[] memory swapPath, address inputToken)
        internal
        view
        returns (address)
    {
        address outputToken = inputToken;
        Market.Props[] memory markets = MarketUtils.getSwapPathMarkets(dataStore, swapPath);
        uint256 marketCount = markets.length;

        for (uint256 i; i < marketCount; i++) {
            Market.Props memory market = markets[i];
            outputToken = MarketUtils.getOppositeToken(outputToken, market);
        }

        return outputToken;
    }

    /**
     * Performs a swap on a single market.
     *
     * @param params  The parameters for the swap.
     * @param _params The parameters for the swap on this specific market.
     * @return The token and amount that was swapped.
     */
    function _swap(SwapParams memory params, _SwapParams memory _params) internal returns (address, uint256) {
        SwapCache memory cache;

        if (_params.tokenIn != _params.market.longToken && _params.tokenIn != _params.market.shortToken) {
            revert Errors.InvalidTokenIn(_params.tokenIn, _params.market.marketToken);
        }

        MarketUtils.validateSwapMarket(params.dataStore, _params.market);

        cache.tokenOut = MarketUtils.getOppositeToken(_params.tokenIn, _params.market);
        cache.tokenInPrice = params.oracle.getPrimaryPrice(_params.tokenIn);
        cache.tokenOutPrice = params.oracle.getPrimaryPrice(cache.tokenOut);

        //计算priceImpact
        cache.priceImpactUsd = SwapPricingUtils.getPriceImpactUsd(
            SwapPricingUtils.GetPriceImpactUsdParams(
                params.dataStore,
                _params.market,
                _params.tokenIn,
                cache.tokenOut,
                cache.tokenInPrice.midPrice(),
                cache.tokenOutPrice.midPrice(),
                (_params.amountIn * cache.tokenInPrice.midPrice()).toInt256(),
                -(_params.amountIn * cache.tokenInPrice.midPrice()).toInt256(),
                true // includeVirtualInventoryImpact
            )
        );

        //计算swapFees
        SwapPricingUtils.SwapFees memory fees = SwapPricingUtils.getSwapFees(
            params.dataStore,
            _params.market.marketToken,
            _params.amountIn,
            cache.priceImpactUsd > 0, // forPositiveImpact
            params.uiFeeReceiver,
            ISwapPricingUtils.SwapPricingType.TwoStep
        );

        //累计整个池子的feeReceiverAmount
        FeeUtils.incrementClaimableFeeAmount(
            params.dataStore,
            params.eventEmitter,
            _params.market.marketToken,
            _params.tokenIn,
            fees.feeReceiverAmount,
            Keys.SWAP_FEE_TYPE
        );

        //累计整个池子的uiFeeAmount
        FeeUtils.incrementClaimableUiFeeAmount(
            params.dataStore,
            params.eventEmitter,
            params.uiFeeReceiver,
            _params.market.marketToken,
            _params.tokenIn,
            fees.uiFeeAmount,
            Keys.UI_SWAP_FEE_TYPE
        );

        if (cache.priceImpactUsd > 0) {
            cache.amountIn = fees.amountAfterFees;
            //如果swap对池子产生了有利英雄，swapImpactPool会支付与priceImpactUsd等价值的tokenOut
            //如果swapImpactPool中的tokenOut数量不足，则记录未支付的价值cappedDiffUsd
            (cache.priceImpactAmount, cache.cappedDiffUsd) = MarketUtils.applySwapImpactWithCap(
                params.dataStore,
                params.eventEmitter,
                _params.market.marketToken,
                cache.tokenOut,
                cache.tokenOutPrice,
                cache.priceImpactUsd
            );

            //从swapImpactPool中支付与cappedDiffUsd等价值的tokenIn
            if (cache.cappedDiffUsd != 0) {
                (cache.tokenInPriceImpactAmount, /* uint256 cappedDiffUsd */ ) = MarketUtils.applySwapImpactWithCap(
                    params.dataStore,
                    params.eventEmitter,
                    _params.market.marketToken,
                    _params.tokenIn,
                    cache.tokenInPrice,
                    cache.cappedDiffUsd.toInt256()
                );

                //将这些tokenIn加到用户的amountIn数量上，待用户swap
                cache.amountIn += cache.tokenInPriceImpactAmount.toUint256();
            }

            // 计算用户swap得到的token数量amountOut，对资金池有利是不用交swapFees
            cache.amountOut = cache.amountIn * cache.tokenInPrice.min / cache.tokenOutPrice.max;
            //记录LP资金池付出的tokenOut
            cache.poolAmountOut = cache.amountOut;
            //将上面swapImpactPool支付的tokenOut算到用户得到的token数量上
            cache.amountOut += cache.priceImpactAmount.toUint256();
        } else {
            //如果是对资金池平衡产生了不利影响，则需要从tokenIn中扣除等价值的token交给SwapImpactPool
            (cache.priceImpactAmount, /* uint256 cappedDiffUsd */ ) = MarketUtils.applySwapImpactWithCap(
                params.dataStore,
                params.eventEmitter,
                _params.market.marketToken,
                _params.tokenIn,
                cache.tokenInPrice,
                cache.priceImpactUsd
            );

            if (fees.amountAfterFees <= (-cache.priceImpactAmount).toUint256()) {
                revert Errors.SwapPriceImpactExceedsAmountIn(fees.amountAfterFees, cache.priceImpactAmount);
            }

            //从扣除费用后的tokenIn的数量中再减去缴纳的给SwapImpactPool的token数量，然后计算用户得到tokenOut的数量
            cache.amountIn = fees.amountAfterFees - (-cache.priceImpactAmount).toUint256();
            cache.amountOut = cache.amountIn * cache.tokenInPrice.min / cache.tokenOutPrice.max;
            //记录LP资金池付出的tokenOut
            cache.poolAmountOut = cache.amountOut;
        }

        // 将用户应得的amountOut数量的token交易给下一个market或者receiver
        if (_params.receiver != _params.market.marketToken) {
            MarketToken(payable(_params.market.marketToken)).transferOut(
                cache.tokenOut, _params.receiver, cache.amountOut, _params.shouldUnwrapNativeToken
            );
        }
        //todo
        MarketUtils.applyDeltaToPoolAmount(
            params.dataStore,
            params.eventEmitter,
            _params.market,
            _params.tokenIn,
            (cache.amountIn + fees.feeAmountForPool).toInt256()
        );

        // the poolAmountOut excludes the positive price impact amount
        // as that is deducted from the swap impact pool instead
        MarketUtils.applyDeltaToPoolAmount(
            params.dataStore, params.eventEmitter, _params.market, cache.tokenOut, -cache.poolAmountOut.toInt256()
        );

        MarketUtils.MarketPrices memory prices = MarketUtils.MarketPrices(
            params.oracle.getPrimaryPrice(_params.market.indexToken),
            _params.tokenIn == _params.market.longToken ? cache.tokenInPrice : cache.tokenOutPrice,
            _params.tokenIn == _params.market.shortToken ? cache.tokenInPrice : cache.tokenOutPrice
        );

        //验证swap后资金池的进来的token有没有超过最大限制
        MarketUtils.validatePoolAmount(params.dataStore, _params.market, _params.tokenIn);

        //验证swap后tokenOut的数量是否满足其对应的isLong的仓位的保证金乘以reserveFactor
        MarketUtils.validateReserve(
            params.dataStore, _params.market, prices, cache.tokenOut == _params.market.longToken
        );
        //验证swap后market中仓位的pnl和资金池中的token当前的价值的比率，是否超过了设置的最大比率，这实际上是确认资金池中的价值要能保证赔付给用户的盈利
        MarketUtils.validateMaxPnl(
            params.dataStore,
            _params.market,
            prices,
            _params.tokenIn == _params.market.longToken
                ? Keys.MAX_PNL_FACTOR_FOR_DEPOSITS
                : Keys.MAX_PNL_FACTOR_FOR_WITHDRAWALS,
            cache.tokenOut == _params.market.shortToken
                ? Keys.MAX_PNL_FACTOR_FOR_WITHDRAWALS
                : Keys.MAX_PNL_FACTOR_FOR_DEPOSITS
        );

        SwapPricingUtils.EmitSwapInfoParams memory emitSwapInfoParams;

        emitSwapInfoParams.orderKey = params.key;
        emitSwapInfoParams.market = _params.market.marketToken;
        emitSwapInfoParams.receiver = _params.receiver;
        emitSwapInfoParams.tokenIn = _params.tokenIn;
        emitSwapInfoParams.tokenOut = cache.tokenOut;
        emitSwapInfoParams.tokenInPrice = cache.tokenInPrice.min;
        emitSwapInfoParams.tokenOutPrice = cache.tokenOutPrice.max;
        emitSwapInfoParams.amountIn = _params.amountIn;
        emitSwapInfoParams.amountInAfterFees = fees.amountAfterFees;
        emitSwapInfoParams.amountOut = cache.amountOut;
        emitSwapInfoParams.priceImpactUsd = cache.priceImpactUsd;
        emitSwapInfoParams.priceImpactAmount = cache.priceImpactAmount;
        emitSwapInfoParams.tokenInPriceImpactAmount = cache.tokenInPriceImpactAmount;

        SwapPricingUtils.emitSwapInfo(params.eventEmitter, emitSwapInfoParams);

        SwapPricingUtils.emitSwapFeesCollected(
            params.eventEmitter,
            params.key,
            _params.market.marketToken,
            _params.tokenIn,
            cache.tokenInPrice.min,
            Keys.SWAP_FEE_TYPE,
            fees
        );

        return (cache.tokenOut, cache.amountOut);
    }
}
