import CoreImage
import UIKit

/// High-contrast reading modes applied live to the camera preview and to frozen photos.
nonisolated enum ContrastMode: String, CaseIterable, Sendable {
    case normal
    case whiteOnBlack
    case yellowOnBlack
    case blackOnWhite

    private static let key = "contrastMode"

    static func loadSaved() -> ContrastMode {
        ContrastMode(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .normal
    }

    func save() { UserDefaults.standard.set(rawValue, forKey: Self.key) }

    var next: ContrastMode {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    /// String Catalog key with the big on-screen name of the mode.
    var titleKey: String {
        switch self {
        case .normal: return "contrast_normal"
        case .whiteOnBlack: return "contrast_white_on_black"
        case .yellowOnBlack: return "contrast_yellow_on_black"
        case .blackOnWhite: return "contrast_black_on_white"
        }
    }

    /// Maps the luminance of the picture to two colours: dark pixels (text) -> first, light pixels (paper) -> second.
    func apply(to image: CIImage) -> CIImage {
        let text: CIColor, paper: CIColor
        switch self {
        case .normal: return image
        case .whiteOnBlack: text = CIColor(red: 1, green: 1, blue: 1); paper = CIColor(red: 0, green: 0, blue: 0)
        case .yellowOnBlack: text = CIColor(red: 1, green: 0.84, blue: 0.04); paper = CIColor(red: 0, green: 0, blue: 0)
        case .blackOnWhite: text = CIColor(red: 0, green: 0, blue: 0); paper = CIColor(red: 1, green: 1, blue: 1)
        }
        return image
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.0,
                kCIInputContrastKey: 1.8,
                kCIInputBrightnessKey: 0.05
            ])
            .applyingFilter("CIFalseColor", parameters: ["inputColor0": text, "inputColor1": paper])
    }

    private static let context = CIContext()

    /// Applies the mode to a still image (used for frozen photos).
    static func apply(_ mode: ContrastMode, to image: UIImage) -> UIImage {
        guard mode != .normal, let ci = CIImage(image: image) else { return image }
        let out = mode.apply(to: ci)
        guard let cg = context.createCGImage(out, from: out.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }
}
