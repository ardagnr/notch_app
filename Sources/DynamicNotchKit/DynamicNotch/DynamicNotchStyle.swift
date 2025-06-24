//
//  DynamicNotchStyle.swift
//  DynamicNotchKit
//
//  Created by Kai Azim on 2025-04-18.
//

import SwiftUI

/// The style of a DynamicNotch.
///
/// The style determines how the notch appears on the screen.
/// It is generally recommended to use the ``auto`` style, which will automatically choose the best style based on the screen size.
/// However, you can also use the ``notch`` or ``floating`` styles to force the notch to appear in a specific way.
///
/// ## Complex Usage
///
/// Custom border radii can easily complement a rounded user interface.
/// Remember this formula instead of eyeballing the corner radius, if you haven't already!
/// ```
/// Outer Radius = Inner Radius + Padding
/// ```
/// In order to set a custom corner radius, use the following cases:
/// - ``notch(topCornerRadius:bottomCornerRadius:)``
/// - ``floating(cornerRadius:)``
///
public enum DynamicNotchStyle: Sendable {
    /// Notch-style, meant to be used on screens with a notch
    ///
    /// Note that `topCornerRadius` and `bottomCornerRadius` are only use when the notch is in the expanded state.
    case notch(
        topCornerRadius: CGFloat,
        bottomCornerRadius: CGFloat
    )

    /// Floating style, to be used on screens without a notch
    case floating(
        cornerRadius: CGFloat
    )

    /// Automatically choose the style based on the screen
    case auto

    /// A preset notch style, made to look good in most cases.
    public static let notch: DynamicNotchStyle = .notch(topCornerRadius: 18, bottomCornerRadius: 24)

    /// A preset floating style, made to look good in most cases.
    public static let floating: DynamicNotchStyle = .floating(cornerRadius: 20)

    var isNotch: Bool {
        if case .notch = self {
            true
        } else {
            false
        }
    }

    var isFloating: Bool {
        if case .floating = self {
            true
        } else {
            false
        }
    }

    var openingAnimation: Animation {
        if isNotch {
            .spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2)
        } else {
            .spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0.15)
        }
    }

    var closingAnimation: Animation {
        .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1)
    }

    var conversionAnimation: Animation {
        .spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.1)
    }
}

extension DynamicNotchStyle: Equatable {
    public static func == (lhs: DynamicNotchStyle, rhs: DynamicNotchStyle) -> Bool {
        switch (lhs, rhs) {
        case let (.notch(lhsTop, lhsBottom), .notch(rhsTop, rhsBottom)):
            lhsTop == rhsTop && lhsBottom == rhsBottom
        case let (.floating(lhsRadius), .floating(rhsRadius)):
            lhsRadius == rhsRadius
        case (.auto, .auto):
            true
        default:
            false
        }
    }
}
