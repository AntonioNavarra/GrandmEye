//
//  MagnificationSettings.swift
//  EasyReader
//
//  Created by Antonio Navarra on 24/11/25.
//

import Foundation
import CoreGraphics

/// Model for camera/magnification related settings.
struct MagnificationSettings: Codable, Sendable {

    // MARK: - Properties

    var defaultZoomLevel: CGFloat = 2.5
    var minZoomLevel: CGFloat = 1.0
    var maxZoomLevel: CGFloat = 10.0
    var zoomStep: CGFloat = 0.1

    /// If true, the app starts with the last zoom level used by the user (when available).
    var rememberLastZoom: Bool = true

    /// The last zoom level set by the user (optional).
    var lastUsedZoom: CGFloat?

    // MARK: - Constants

    private static let userDefaultsKey = "magnificationSettings"

    // MARK: - Computed Properties

    /// Determines the initial zoom level at app launch.
    var startingZoom: CGFloat {
        if rememberLastZoom, let last = lastUsedZoom {
            return clampedZoom(last)
        }
        return defaultZoomLevel
    }

    /// Closed range suitable for SwiftUI sliders.
    var zoomRange: ClosedRange<CGFloat> {
        minZoomLevel...maxZoomLevel
    }

    // MARK: - Logic

    /// Ensures a zoom value stays within the configured min/max limits.
    func clampedZoom(_ level: CGFloat) -> CGFloat {
        min(max(level, minZoomLevel), maxZoomLevel)
    }

    /// Updates the last used zoom (clamped).
    mutating func updateLastUsedZoom(_ level: CGFloat) {
        self.lastUsedZoom = clampedZoom(level)
    }

    // MARK: - Persistence

    /// Loads settings from UserDefaults, or returns defaults if not found / decoding fails.
    static func load() -> MagnificationSettings {
        guard
            let data = UserDefaults.standard.data(forKey: userDefaultsKey),
            let decoded = try? JSONDecoder().decode(MagnificationSettings.self, from: data)
        else {
            return MagnificationSettings()
        }

        return decoded
    }

    /// Saves the current state into UserDefaults.
    func save() {
        guard let encoded = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.userDefaultsKey)
    }
}

