// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../data/DataStore.sol";
import "../data/Keys.sol";
import "../error/ErrorUtils.sol";
import "../library/AccountUtils.sol";

import "./IWNT.sol";

/**
 * @title TokenUtils
 * @dev Library for token functions, helps with transferring of tokens and native token functions.
 */
library TokenUtils {
    using Address for address;
    using SafeERC20 for IERC20;

    event TokenTransferReverted(string reason, bytes returndata);
    event NativeTokenTransferReverted(string reason);

    function wnt(DataStore dataStore) internal view returns (address) {
        return dataStore.getAddress(Keys.WNT);
    }

    function transfer(
        DataStore dataStore,
        address token,
        address receiver,
        uint256 amount
    ) internal {
        if (amount == 0) {
            return;
        }
        AccountUtils.validateReceiver(receiver);

        uint256 gasLimit = dataStore.getUint(Keys.tokenTransferGasLimit(token));
        if (gasLimit == 0) {
            revert Errors.EmptyTokenTranferGasLimit(token);
        }

        (bool success0, ) = nonRevertingTransferWithGasLimit(
            IERC20(token),
            receiver,
            amount,
            gasLimit
        );

        if (success0) {
            return;
        }

        // HOLDING_ADRESS is the address that holds the tokens in case of a failed transfer.
        address holdingAddress = dataStore.getAddress(Keys.HOLDING_ADDRESS);
        if (holdingAddress == address(0)) {
            revert Errors.EmptyHoldingAddress();
        }

        (
            bool success1,
            bytes memory returndata
        ) = nonRevertingTransferWithGasLimit(
                IERC20(token),
                holdingAddress,
                amount,
                gasLimit
            );

        if (success1) {
            return;
        }

        // Even if the transaction is rolled back, the events will still be recorded on the blockchain.
        (string memory reason, ) = ErrorUtils.getRevertMessage(returndata);
        emit TokenTransferReverted(reason, returndata);

        revert Errors.TokenTransferError(token, receiver, amount);
    }

    function sendNativeToken(
        DataStore dataStore,
        address receiver,
        uint256 amount
    ) internal {
        if (amount == 0) {
            return;
        }
        AccountUtils.validateReceiver(receiver);

        uint256 gasLimit = dataStore.getUint(
            Keys.NATIVE_TOKEN_TRANSFER_GAS_LIMIT
        );
        // Native token first,Wrapped token later. Maybe there's some room for optimization
        bool success;
        assembly {
            success := call(gasLimit, receiver, amount, 0, 0, 0, 0)
        }
        if (success) {
            return;
        }

        depositAndSendWrappedNativeToken(dataStore, receiver, amount);
    }

    function depositAndSendWrappedNativeToken(
        DataStore dataStore,
        address receiver,
        uint256 amount
    ) internal {
        if (amount == 0) {
            return;
        }
        AccountUtils.validateReceiver(receiver);

        address _wnt = wnt(dataStore);
        IWNT(_wnt).deposit{value: amount}();

        transfer(dataStore, _wnt, receiver, amount);
    }

    function withdrawAndSendNativeToken(
        DataStore dataStore,
        address _wnt,
        address receiver,
        uint256 amount
    ) internal {
        if (amount == 0) {
            return;
        }
        AccountUtils.validateReceiver(receiver);

        IWNT(_wnt).withdraw(amount);

        uint256 gasLimit = dataStore.getUint(
            Keys.NATIVE_TOKEN_TRANSFER_GAS_LIMIT
        );

        bool success;
        assembly {
            success := call(gasLimit, receiver, amount, 0, 0, 0, 0)
        }
        if (success) {
            return;
        }

        depositAndSendWrappedNativeToken(dataStore, receiver, amount);
    }

    /**
     * Transfers the specified amount of ERC20 token to the specified receiver
     * with a gas limit.
     */
    function nonRevertingTransferWithGasLimit(
        IERC20 token,
        address to,
        uint256 amount,
        uint256 gasLimit
    ) internal returns (bool, bytes memory) {
        bytes memory data = abi.encodeWithSelector(
            token.transfer.selector,
            to,
            amount
        );
        (bool success, bytes memory returndata) = address(token).call{
            gas: gasLimit
        }(data);

        if (success) {
            if (returndata.length == 0) {
                if (address(token).code.length > 0) {
                    return (false, "Call to non-contract");
                }
            }

            if (returndata.length > 0 && !abi.decode(returndata, (bool))) {
                return (false, returndata);
            }

            return (true, returndata);
        }
        return (false, returndata);
    }
}
