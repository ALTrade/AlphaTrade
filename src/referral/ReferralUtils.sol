// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./IReferralStorage.sol";

library ReferralUtils {
    function setTraderReferralCode(
        IReferralStorage referralStorage,
        address account,
        bytes32 referralCode
    ) internal {
        if (referralCode == bytes32(0)) {
            return;
        }

        // skip setting of the referral code if the user already has a referral code
        if (referralStorage.traderReferralCodes(account) != bytes32(0)) {
            return;
        }

        referralStorage.setTraderReferralCode(account, referralCode);
    }
}
