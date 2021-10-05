//
//  AppStorePaymentObserver.swift
//  AppStorePaymentObserver
//
//  Created by pronebird on 03/09/2021.
//  Copyright © 2021 Mullvad VPN AB. All rights reserved.
//

import Foundation
import StoreKit

protocol AppStorePaymentObserver: AnyObject {
    func appStorePaymentManager(
        _ manager: AppStorePaymentManager,
        transaction: SKPaymentTransaction,
        accountToken: String?,
        didFailWithError error: AppStorePaymentManager.Error)

    func appStorePaymentManager(
        _ manager: AppStorePaymentManager,
        transaction: SKPaymentTransaction,
        accountToken: String,
        didFinishWithResponse response: REST.CreateApplePaymentResponse)
}
