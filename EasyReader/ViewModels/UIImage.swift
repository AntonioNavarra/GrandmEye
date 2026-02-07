//
//  UIImage+FixOrientation.swift
//  EasyReader
//
//  Created by Antonio Navarra on 25/11/25.
//

import UIKit

extension UIImage {
    /// Returns an image whose pixel data is rotated so that its imageOrientation is .up.
    /// If the image is already .up, it returns self.
    nonisolated func fixOrientation() -> UIImage {
        // If already correct, return as is
        if imageOrientation == .up {
            return self
        }
        
        // Build transform to apply
        var transform = CGAffineTransform.identity
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: -.pi / 2)
        case .up, .upMirrored:
            break
        @unknown default:
            break
        }
        
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }
        
        // Create a new context with correct size (note: width/height swap for left/right orientations)
        guard let cgImage = self.cgImage else { return self }
        let ctxWidth = Int(size.width)
        let ctxHeight = Int(size.height)
        
        guard let colorSpace = cgImage.colorSpace,
              let ctx = CGContext(
                data: nil,
                width: ctxWidth,
                height: ctxHeight,
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: cgImage.bitmapInfo.rawValue
              ) else {
            return self
        }
        
        ctx.concatenate(transform)
        
        let drawRect: CGRect
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            drawRect = CGRect(x: 0, y: 0, width: size.height, height: size.width)
        default:
            drawRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        }
        
        ctx.draw(cgImage, in: drawRect)
        
        guard let newCGImage = ctx.makeImage() else { return self }
        return UIImage(cgImage: newCGImage, scale: scale, orientation: .up)
    }
}
