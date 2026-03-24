# GrandmEye 👁️

<div align="center">
<img width="500px" height="500px" alt="standard" src="https://github.com/user-attachments/assets/ed4b24a1-0d56-47b0-872d-1bbbcc7f4442" />

**Smart Magnifier & Text Reader for iOS**

[![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square&logo=swift)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-16.0+-blue?style=flat-square&logo=apple)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-purple?style=flat-square&logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![Vision](https://img.shields.io/badge/Vision-OCR-green?style=flat-square)](https://developer.apple.com/documentation/vision)
[![License](https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square)](LICENSE)

*Turn your iPhone into a powerful reading assistant — magnify, freeze, and read any text aloud, entirely on-device.*

[Features](#-features) • [Installation](#-installation) • [Usage](#-usage) • [Architecture](#-architecture) • [Privacy](#-privacy)

</div>

---

## 👁️ Overview

GrandmEye is an accessibility-focused iOS app designed to help users — especially elderly people — read small print comfortably and independently. Combining real-time camera magnification, image freezing, and on-device OCR text recognition, GrandmEye turns any iPhone into a powerful reading aid. No internet connection required. No account needed. No data leaves your device.

### 🎯 What Makes GrandmEye Special

- **🔍 Up to 10x Magnification**: Smooth, real-time zoom with a single-finger slider
- **❄️ Freeze & Read**: Capture any frame and inspect it without shaking
- **🗣️ On-Device OCR**: Select any text area and have it read aloud via Apple's Vision Framework
- **♿ Accessibility First**: Designed with VoiceOver labels, haptic feedback, and readable typography
- **🔒 100% Private**: All processing happens locally — no servers, no tracking

---

## ✨ Features

### 🔍 Live Magnification
- **Real-time Camera Feed** — Instant zoom from 1x to 10x
- **Smooth Zoom Slider** — Precise control with a custom UI component
- **Remember Last Zoom** — Option to restore last used zoom level on next launch
- **Configurable Default Zoom** — Set your preferred starting zoom in Settings

### ❄️ Freeze & Inspect
- **One-Tap Freeze** — Capture the live frame with a single button press
- **Pan & Zoom** — Navigate the frozen image freely with drag gestures
- **Clamped Panning** — Smart boundary detection to keep the image in view

### 🗣️ Text Recognition (OCR)
- **Custom Selection Area** — Draw a crop region directly on the frozen image
- **On-Device Processing** — Powered by Apple's Vision Framework, no cloud required
- **Read Aloud** — Recognized text is spoken using AVSpeechSynthesizer
- **Transcription View** — Clear, large-font display of the recognized text

### 🔦 & 💾 Utilities
- **Built-in Flashlight** — Illuminate dark labels and documents
- **Save to Camera Roll** — Save magnified captures locally via PhotoManager
- **Audio Feedback** — Subtle sounds for key interactions
- **Haptic Feedback** — Tactile confirmation on button taps and actions

### 🌍 Localization
- **Full Italian & English support** via `Localizable.xcstrings` String Catalog
- **Type-safe string access** through a centralized `Localization` enum
- Device language automatically selects the correct language

---

## 📱 Screenshots

| Live Camera View | Freeze & Text Selection |
|---|---|
| <img src="https://github.com/user-attachments/assets/5821dc04-10a1-48f2-8b77-3be3346adc95" alt="GrandmEye Live Camera View" width="260" /> | <img src="https://github.com/user-attachments/assets/fa69cfd4-0894-43aa-843c-d2dc39a8f62e" alt="GrandmEye Freeze and Text Selection" width="260" /> |


---

## 🚀 Installation

### Prerequisites
- **Xcode 15.0+**
- **iOS 16.0+**
- **iPhone** with rear camera
- Physical device recommended (camera features require real hardware)

### Setup Instructions

1. **Clone the Repository**
   ```bash
   git clone https://github.com/antonio-navarra/GrandmEye.git
   cd GrandmEye
