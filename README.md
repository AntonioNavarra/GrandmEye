# GrandmEye 👁️

<img width="500" height="500" alt="standard" src="https://github.com/user-attachments/assets/41ba59b0-d6d3-4e88-bff1-49ebe90833c8" />

## Project Overview
GrandmEye is an accessibility-focused iOS magnifier app designed to help users — especially elderly people — read small text comfortably and independently. By combining real-time camera magnification, image freezing, and on-device OCR text recognition, GrandmEye turns any iPhone into a powerful reading assistant. No internet connection required.

## Features
- **Live Magnification**: Real-time camera zoom from 1x to 10x with smooth slider control
- **Freeze & Inspect**: Capture and freeze any frame to read it calmly without shaking
- **Text Recognition (OCR)**: Select any area of a frozen image and have it read aloud using on-device Vision Framework
- **Built-in Flashlight**: Illuminate poorly lit labels and documents directly from the app
- **Save to Camera Roll**: Save magnified captures to your photo library for future reference
- **Customizable Settings**: Configure default zoom, remember last zoom level, audio feedback, and haptic feedback
- **Full Localization**: Complete Italian and English support via String Catalog (Localizable.xcstrings)
- **Accessibility First**: Designed with accessibility labels, haptic feedback, and high-contrast support

## Project Structure
The project follows a clean MVVM architecture with clear separation of concerns:

```
GrandmEye/
├── Views/
│   ├── CameraView.swift          # Main camera interface and controls
│   ├── FreezeView.swift          # Frozen image viewer with pan & zoom
│   ├── SettingsView.swift        # Settings sheet
│   └── TranscriptionView.swift   # OCR result display
├── Managers/
│   ├── OCRManager.swift          # Vision Framework text recognition
│   ├── AudioManager.swift        # Sound feedback
│   ├── HapticManager.swift       # Haptic feedback
│   └── PhotoManager.swift        # Camera roll saving
├── Models/
│   ├── AppSettings.swift         # General app preferences
│   └── MagnificationSettings.swift # Zoom configuration
├── Components/
│   ├── CircleButton.swift        # Reusable circular button
│   ├── SettingsCard.swift        # Settings section card
│   └── ZoomSlider.swift          # Custom zoom control
├── Localization/
│   ├── Localizable.xcstrings     # IT + EN string catalog
│   └── Localization.swift        # Type-safe localization enum
└── Resources/
    └── Assets.xcassets
```

## Technologies Used
- **Swift** and **SwiftUI** for the iOS application
- **AVFoundation** for live camera capture and torch control
- **Vision Framework** for on-device OCR text recognition
- **Swift Data / UserDefaults** for local settings persistence
- **UIKit** for camera preview integration (`AVCaptureVideoPreviewLayer`)

## Requirements
- iOS 16.0+
- iPhone with rear camera
- Xcode 15+

## Installation
To run the project locally:
1. Clone the repository:
   ```sh
   git clone https://github.com/antonio-navarra/GrandmEye.git
   ```
2. Open `GrandmEye.xcodeproj` in Xcode
3. Select your target device or simulator
4. Build and run (⌘ + R)

> **Note:** Camera and photo library features require a physical device. The simulator does not support live camera input.

## Permissions Required
| Permission | Purpose |
|---|---|
| Camera | Real-time magnification and freeze capture |
| Photo Library (Add Only) | Saving frozen images to camera roll |

## Future Improvements
- iCloud sync for saved images across devices
- Color filter modes (e.g. night mode, high contrast overlays)
- Apple Watch companion app for quick torch control
- VoiceOver full compatibility audit
- iPad optimized layout

## Privacy
GrandmEye processes all images and text **entirely on-device**. No data is sent to external servers. No account required. No analytics. See [Privacy Policy](./privacy.html) for details.

## License
This project is distributed under the MIT license. See the `LICENSE` file for more details.

---

GrandmEye was built to make everyday reading accessible for everyone — combining the simplicity of a magnifying glass with the power of modern iOS technology.
