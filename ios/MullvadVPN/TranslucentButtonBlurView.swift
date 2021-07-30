//
//  TranslucentButtonBlurView.swift
//  MullvadVPN
//
//  Created by pronebird on 20/03/2019.
//  Copyright © 2019 Mullvad VPN AB. All rights reserved.
//

import UIKit

private let kButtonCornerRadius = CGFloat(4)

class TranslucentButtonBlurView: UIVisualEffectView {
    init(button: AppButton) {
        let effect = UIBlurEffect(style: button.style.blurEffectStyle)

        super.init(effect: effect)

        button.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(button)

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: contentView.topAnchor),
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        layer.cornerRadius = kButtonCornerRadius
        layer.maskedCorners = button.style.cornerMask
        layer.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension AppButton.Style {
    var cornerMask: CACornerMask {
        switch self {
        case .translucentDangerSplitLeft:
            return [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        case .translucentDangerSplitRight:
            return [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        default:
            return [
                .layerMinXMinYCorner, .layerMinXMaxYCorner,
                .layerMaxXMinYCorner, .layerMaxXMaxYCorner
            ]
        }
    }

    var blurEffectStyle: UIBlurEffect.Style {
        switch self {
        case .translucentDangerSplitLeft, .translucentDangerSplitRight, .translucentDanger:
            if #available(iOS 13.0, *) {
                return .systemUltraThinMaterialDark
            } else {
                return .dark
            }
        default:
            return .light
        }
    }
}
