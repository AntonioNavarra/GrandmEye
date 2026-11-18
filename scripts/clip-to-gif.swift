// Turns a screen recording into a looping GIF.
//   swift scripts/clip-to-gif.swift in.mp4 out.gif [width=300] [fps=10] [ranges]
// `ranges` cuts the recording to the parts worth showing, in seconds: "30.5-32.5,41-46,50-58".
// No dependencies beyond AVFoundation and ImageIO (both in the system).
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count >= 3 else { print("usage: clip-to-gif.swift in.mp4 out.gif [width] [fps] [ranges]"); exit(2) }
let width = arguments.count > 3 ? Int(arguments[3]) ?? 300 : 300
let fps = arguments.count > 4 ? Double(arguments[4]) ?? 10 : 10
let asset = AVURLAsset(url: URL(fileURLWithPath: arguments[1]))
let duration = CMTimeGetSeconds(asset.duration)
let ranges: [(Double, Double)] = arguments.count > 5
    ? arguments[5].split(separator: ",").compactMap { part in
        let bounds = part.split(separator: "-").compactMap { Double($0) }
        return bounds.count == 2 ? (bounds[0], bounds[1]) : nil
    }
    : [(0, duration)]
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
let natural = asset.tracks(withMediaType: .video).first?.naturalSize ?? CGSize(width: 1170, height: 2532)
generator.maximumSize = CGSize(width: CGFloat(width), height: CGFloat(width) * natural.height / natural.width)

var times: [Double] = []
for (start, end) in ranges {
    var time = start
    while time < end { times.append(time); time += 1 / fps }
}
guard let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: arguments[2]) as CFURL, UTType.gif.identifier as CFString, times.count, nil) else { exit(1) }
CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]] as CFDictionary
var frames = 0
for time in times {
    // A frame that cannot be read is held from the previous one, so the declared count always matches.
    if let image = try? generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil) {
        CGImageDestinationAddImage(destination, image, frameProperties)
        frames += 1
    }
}
guard frames == times.count, CGImageDestinationFinalize(destination) else { print("failed: \(frames) of \(times.count) frames"); exit(1) }
print("\(frames) frames at \(fps) fps, from \(Int(duration)) s of recording")
