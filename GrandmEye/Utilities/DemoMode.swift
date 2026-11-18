#if DEBUG
import UIKit

/// Debug-only helpers to record the README media on the simulator, which has no camera.
///   -demoImagePath <png>   use this picture as the camera view and as every photo taken
///   -demoClip YES          drive the app through a paced tour (simple mode, reading, contrast, still photo)
enum DemoMode {
    static var image: UIImage? {
        UserDefaults.standard.string(forKey: "demoImagePath").flatMap { UIImage(contentsOfFile: $0) }
    }
    static var isClip: Bool { UserDefaults.standard.bool(forKey: "demoClip") }
}
#endif
