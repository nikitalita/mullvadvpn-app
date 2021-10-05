//
//  Result+UIBackgroundFetchResult.swift
//  Result+UIBackgroundFetchResult
//
//  Created by pronebird on 07/09/2021.
//  Copyright © 2021 Mullvad VPN AB. All rights reserved.
//

import UIKit

extension Result where Success == TunnelManager.KeyRotationResult {
    var backgroundFetchResult: UIBackgroundFetchResult {
        switch self.asConcreteType() {
        case .success(.finished):
            return .newData

        case .success(.throttled):
            return .noData

        case .failure:
            return .failed
        }
    }
}

extension Result where Success == RelayCache.FetchResult {
    var backgroundFetchResult: UIBackgroundFetchResult {
        switch self.asConcreteType() {
        case .success(.newContent):
            return .newData

        case .success(.throttled), .success(.sameContent):
            return .noData

        case .failure:
            return .failed
        }
    }
}

extension UIBackgroundFetchResult: CustomStringConvertible {
    public var description: String {
        switch self {
        case .newData:
            return "new data"
        case .noData:
            return "no data"
        case .failed:
            return "failed"
        @unknown default:
            return "unknown (rawValue: \(self.rawValue)"
        }
    }

    func combine(with other: UIBackgroundFetchResult) -> UIBackgroundFetchResult {
        if self == .failed || other == .failed {
            return .failed
        } else if self == .newData || other == .newData {
            return .newData
        } else {
            return .noData
        }
    }
}
