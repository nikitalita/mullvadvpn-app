//
//  AsyncOperation.swift
//  MullvadVPN
//
//  Created by pronebird on 01/06/2020.
//  Copyright © 2020 Mullvad VPN AB. All rights reserved.
//

import Foundation

/// A base implementation of an asynchronous operation
class AsyncOperation: Operation {

    /// A state lock used for manipulating the operation state flags in a thread safe fashion.
    private let stateLock = NSRecursiveLock()

    /// Operation state flags.
    private var _isExecuting = false
    private var _isFinished = false
    private var _isCancelled = false

    final override var isExecuting: Bool {
        return stateLock.withCriticalBlock { _isExecuting }
    }

    final override var isFinished: Bool {
        return stateLock.withCriticalBlock { _isFinished }
    }

    final override var isCancelled: Bool {
        return stateLock.withCriticalBlock { _isCancelled }
    }

    final override var isAsynchronous: Bool {
        return true
    }

    final override func start() {
        stateLock.withCriticalBlock {
            setExecuting(true)
        }
        main()
    }

    override func main() {
        // Override in subclasses
    }

    override func cancel() {
        stateLock.withCriticalBlock {
            if !_isCancelled {
                willChangeValue(for: \.isCancelled)
                _isCancelled = true
                didChangeValue(for: \.isCancelled)
            }
        }
        super.cancel()
    }

    final func finish() {
        stateLock.withCriticalBlock {
            if _isExecuting {
               setExecuting(false)
            }

            if !_isFinished {
                willChangeValue(for: \.isFinished)
                _isFinished = true
                didChangeValue(for: \.isFinished)
            }
        }
    }

    private func setExecuting(_ value: Bool) {
        willChangeValue(for: \.isExecuting)
        _isExecuting = value
        didChangeValue(for: \.isExecuting)
    }
}
