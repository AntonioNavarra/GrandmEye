import SwiftUI

/// A view that displays a frozen image with support for panning.
/// Zoom with a two-finger pinch or with the 2x / 4x / 8x buttons; move with one finger.
struct FreezeView: View {
    // MARK: - Properties
    let image: UIImage
    @Binding var zoomFactor: CGFloat
    /// The part of the picture currently on screen, normalized (0...1, origin top-left).
    @Binding var visibleRect: CGRect
    
    // States for image panning when magnified
    @State private var currentOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    /// Zoom at the moment the pinch started (nil when not pinching).
    @State private var pinchStartZoom: CGFloat?
    private let zoomRange: ClosedRange<CGFloat> = 1.0...10.0
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoomFactor)
                    .offset(x: currentOffset.width + dragOffset.width,
                            y: currentOffset.height + dragOffset.height)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                let start = pinchStartZoom ?? zoomFactor
                                pinchStartZoom = start
                                zoomFactor = min(max(start * value.magnification, zoomRange.lowerBound), zoomRange.upperBound)
                            }
                            .onEnded { _ in pinchStartZoom = nil }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                // Allow panning only if the image is zoomed in
                                if zoomFactor > 1.0 {
                                    dragOffset = value.translation
                                }
                            }
                            .onEnded { value in
                                if zoomFactor > 1.0 {
                                    let newOffset = CGSize(
                                        width: currentOffset.width + value.translation.width,
                                        height: currentOffset.height + value.translation.height
                                    )
                                    withAnimation(.spring()) {
                                        currentOffset = clampOffset(newOffset, viewSize: geometry.size)
                                        dragOffset = .zero
                                    }
                                }
                            }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .onAppear { updateVisibleRect(viewSize: geometry.size) }
                    .onChange(of: currentOffset) { _, _ in updateVisibleRect(viewSize: geometry.size) }
                    .onChange(of: zoomFactor) { _, _ in
                        updateVisibleRect(viewSize: geometry.size)
                        // Keep the picture inside the screen as the zoom changes (no animation while pinching).
                        if pinchStartZoom != nil {
                            currentOffset = clampOffset(currentOffset, viewSize: geometry.size)
                        } else {
                            withAnimation(.spring()) {
                                currentOffset = clampOffset(currentOffset, viewSize: geometry.size)
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - Logic
    
    /// Works out which part of the picture is visible with the current zoom and position.
    private func updateVisibleRect(viewSize: CGSize) {
        guard image.size.width > 0, image.size.height > 0, viewSize.width > 0, viewSize.height > 0 else { return }
        // Size of the picture fitted inside the screen, before zooming.
        let imageRatio = image.size.width / image.size.height
        let fit: CGSize = imageRatio > viewSize.width / viewSize.height
            ? CGSize(width: viewSize.width, height: viewSize.width / imageRatio)
            : CGSize(width: viewSize.height * imageRatio, height: viewSize.height)
        // Where the zoomed picture sits on screen (it zooms around the centre, then moves).
        let shown = CGRect(
            x: viewSize.width / 2 + currentOffset.width - fit.width * zoomFactor / 2,
            y: viewSize.height / 2 + currentOffset.height - fit.height * zoomFactor / 2,
            width: fit.width * zoomFactor,
            height: fit.height * zoomFactor
        )
        let onScreen = shown.intersection(CGRect(origin: .zero, size: viewSize))
        guard !onScreen.isNull, shown.width > 0, shown.height > 0 else { return }
        visibleRect = CGRect(
            x: (onScreen.minX - shown.minX) / shown.width,
            y: (onScreen.minY - shown.minY) / shown.height,
            width: onScreen.width / shown.width,
            height: onScreen.height / shown.height
        )
    }
    
    /// Ensures the image stays within screen bounds during panning
    private func clampOffset(_ offset: CGSize, viewSize: CGSize) -> CGSize {
        let scaledWidth = viewSize.width * zoomFactor
        let scaledHeight = viewSize.height * zoomFactor
        
        let maxX = max(0, (scaledWidth - viewSize.width) / 2)
        let maxY = max(0, (scaledHeight - viewSize.height) / 2)
        
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }
}
