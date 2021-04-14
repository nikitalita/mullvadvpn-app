//
//  AutomaticKeyboardResponder.swift
//  MullvadVPN
//
//  Created by pronebird on 24/03/2021.
//  Copyright © 2021 Mullvad VPN AB. All rights reserved.
//

import UIKit
import Logging

class AutomaticKeyboardResponder {
    weak var targetView: UIView?
    private let handler: (UIView, CGFloat) -> Void

    private var showsKeyboard = false
    private var lastKeyboardRect: CGRect?

    private let logger = Logger(label: "AutomaticKeyboardResponder")
    private var presentationFrameObserver: NSKeyValueObservation?

    init<T: UIView>(targetView: T, handler: @escaping (T, CGFloat) -> Void) {
        self.targetView = targetView
        self.handler = { (view, adjustment) in
            handler(view as! T, adjustment)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIWindow.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIWindow.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidHide(_:)), name: UIWindow.keyboardDidHideNotification, object: nil)
    }

    func updateContentInsets() {
        guard let keyboardRect = lastKeyboardRect else { return }

        adjustContentInsets(keyboardRect: keyboardRect)
    }

    // MARK: - Keyboard notifications

    @objc private func keyboardWillShow(_ notification: Notification) {
        showsKeyboard = true

        addPresentationControllerObserver()
        handleKeyboardNotification(notification)
    }

    @objc private func keyboardDidHide(_ notification: Notification) {
        showsKeyboard = false
        presentationFrameObserver = nil
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard showsKeyboard else { return }

        handleKeyboardNotification(notification)
    }

    // MARK: - Private

    private func handleKeyboardNotification(_ notification: Notification) {
        guard let keyboardFrameValue = notification.userInfo?[UIWindow.keyboardFrameEndUserInfoKey] as? NSValue else { return }

        lastKeyboardRect = keyboardFrameValue.cgRectValue

        self.adjustContentInsets(keyboardRect: keyboardFrameValue.cgRectValue)
    }

    private func addPresentationControllerObserver() {
        guard isFormSheetPresentation else { return }

        // Presentation controller follows the keyboard on iPad.
        // Install the observer to listen for the container view frame and adjust the target view
        // accordingly.
        guard let containerView = presentationContainerView else {
            logger.warning("Cannot determine the container view in form sheet presentation.")
            return
        }

        presentationFrameObserver = containerView.observe(\.frame, options: [.new], changeHandler: { [weak self] (containingView, change) in
            guard let self = self, let keyboardFrameValue = self.lastKeyboardRect else { return }

            self.adjustContentInsets(keyboardRect: keyboardFrameValue)
        })
    }

    /// Returns the first parent controller in the responder chain
    private var parentViewController: UIViewController? {
        var responder: UIResponder? = targetView
        let iterator = AnyIterator { () -> UIResponder? in
            let next = responder?.next
            responder = next
            return next
        }

        return iterator.first { $0 is UIViewController } as? UIViewController
    }

    /// Returns the presentation container view that's moved along with the keyboard on iPad
    private var presentationContainerView: UIView? {
        var currentView = parentViewController?.view
        let iterator = AnyIterator { () -> UIView? in
            let next = currentView?.superview
            currentView = next
            return next
        }

        // Find the container view that private `_UIFormSheetPresentationController` moves
        // along with the keyboard.
        return iterator.first { (view) -> Bool in
            return view.description.starts(with: "<UIDropShadowView")
        }
    }

    private var isFormSheetPresentation: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad &&
            parentViewController?.modalPresentationStyle == .formSheet
    }

    private func adjustContentInsets(keyboardRect: CGRect) {
        guard let targetView = targetView, let superview = targetView.superview else { return }

        // Compute the target view frame within screen coordinates
        let screenRect = superview.convert(targetView.frame, to: nil)

        // Find the intersection between the keyboard and the view
        let intersection = keyboardRect.intersection(screenRect)

        handler(targetView, intersection.height)
    }
}

extension AutomaticKeyboardResponder {

    /// A convenience initializer that automatically assigns the offset to the scroll view subclasses
    convenience init<T: UIScrollView>(targetView: T) {
        self.init(targetView: targetView) { (scrollView, offset) in
            if scrollView.canBecomeFirstResponder {
                scrollView.contentInset.bottom = targetView.isFirstResponder ? offset : 0
                scrollView.scrollIndicatorInsets.bottom = targetView.isFirstResponder ? offset : 0
            } else {
                scrollView.contentInset.bottom = offset
                scrollView.scrollIndicatorInsets.bottom = offset
            }
        }
    }
}
