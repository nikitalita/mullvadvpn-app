//
//  DisconnectSplitButton.swift
//  MullvadVPN
//
//  Created by pronebird on 29/07/2020.
//  Copyright © 2020 Mullvad VPN AB. All rights reserved.
//

import Foundation
import UIKit

class DisconnectSplitButton: UIView {

    private var secondaryButtonSize: CGSize {
        // TODO: make it less hardcoded
        switch self.traitCollection.userInterfaceIdiom {
        case .phone:
            return CGSize(width: 42, height: 42)
        case .pad:
            return CGSize(width: 52, height: 52)
        default:
            return .zero
        }
    }

    let primaryButton = AppButton(style: .translucentDangerSplitLeft)
    let secondaryButton = AppButton(style: .translucentDangerSplitRight)

    private let secondaryButtonWidthConstraint: NSLayoutConstraint
    private let secondaryButtonHeightConstraint: NSLayoutConstraint

    private let stackView: UIStackView

    init() {
        let primaryButtonBlurView = TranslucentButtonBlurView(button: primaryButton)
        let secondaryButtonBlurView = TranslucentButtonBlurView(button: secondaryButton)

        stackView = UIStackView(arrangedSubviews: [primaryButtonBlurView, secondaryButtonBlurView])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .fill
        stackView.spacing = 1

        secondaryButton.setImage(UIImage(named: "IconReload"), for: .normal)

        primaryButton.overrideContentEdgeInsets = true
        secondaryButtonWidthConstraint = secondaryButton.widthAnchor.constraint(equalToConstant: 0)
        secondaryButtonHeightConstraint = secondaryButton.heightAnchor.constraint(equalToConstant: 0)

        super.init(frame: .zero)

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),

            secondaryButtonWidthConstraint,
            secondaryButtonHeightConstraint
        ])

        updateTraitConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.userInterfaceIdiom != previousTraitCollection?.userInterfaceIdiom {
            updateTraitConstraints()
        }
    }

    private func updateTraitConstraints() {
        let newSize = self.secondaryButtonSize
        secondaryButtonWidthConstraint.constant = newSize.width
        secondaryButtonHeightConstraint.constant = newSize.height
        adjustTitleLabelPosition()
    }

    private func adjustTitleLabelPosition() {
        var contentInsets = primaryButton.defaultContentInsets
        contentInsets.left = stackView.spacing + self.secondaryButtonSize.width
        contentInsets.right = 0

        primaryButton.contentEdgeInsets = contentInsets
    }
}
