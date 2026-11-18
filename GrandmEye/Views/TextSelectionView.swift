import SwiftUI

// Optional manual crop selector. Not used by the main reading flow ("Leggi" now reads the whole frame).
// MARK: - Text Selection View

struct TextSelectionView: View {
    let image: UIImage
    var onConfirm: (UIImage) -> Void
    var onCancel: () -> Void
    
    @State private var selectionRect: CGRect = CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.3)
    @State private var userHasInteracted: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let rect = rectFromNormalized(selectionRect, in: size)
            
            ZStack {
                Color.black.opacity(0.8).ignoresSafeArea()
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay(
                        SelectionOverlayShape(selectionRect: rect)
                            .fill(Color.black.opacity(0.6))
                    )
                
                // Interactive Selection Frame
                ZStack {
                    Rectangle()
                        .stroke(Color("AccentColor"), lineWidth: 4)
                        .background(Color.white.opacity(0.01))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    userHasInteracted = true
                                    moveRect(value: value, size: size)
                                }
                        )
                    
                    // Resize Handles
                    ResizeHandle(at: CGPoint(x: rect.minX, y: rect.minY)).gesture(DragGesture().onChanged { v in updateRect(corner: .topLeft, location: v.location, size: size) })
                    ResizeHandle(at: CGPoint(x: rect.maxX, y: rect.minY)).gesture(DragGesture().onChanged { v in updateRect(corner: .topRight, location: v.location, size: size) })
                    ResizeHandle(at: CGPoint(x: rect.minX, y: rect.maxY)).gesture(DragGesture().onChanged { v in updateRect(corner: .bottomLeft, location: v.location, size: size) })
                    ResizeHandle(at: CGPoint(x: rect.maxX, y: rect.maxY)).gesture(DragGesture().onChanged { v in updateRect(corner: .bottomRight, location: v.location, size: size) })
                }
                
                VStack {
                    Text("ui_frame_text") // Localized key
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding(.top, 60)
                    
                    Spacer()
                    
                    HStack(spacing: 30) {
                        Button(action: onCancel) {
                            Text("ui_cancel") // Localized key
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(height: 50)
                                .padding(.horizontal, 30)
                                .background(Color.gray)
                                .cornerRadius(25)
                        }
                        
                        Button(action: {
                            let crop = cropImage(image, normalizedRect: selectionRect, viewSize: size)
                            onConfirm(crop)
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("ui_read") // Localized key
                            }
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .frame(height: 50)
                            .padding(.horizontal, 30)
                            .background(Color("AccentColor"))
                            .cornerRadius(25)
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
        }
    }
    
    // MARK: - Selection Logic
    
    private enum Corner { case topLeft, topRight, bottomLeft, bottomRight }
    
    private func moveRect(value: DragGesture.Value, size: CGSize) {
        let currentW = selectionRect.width
        let currentH = selectionRect.height
        let newX = value.location.x / size.width - currentW / 2
        let newY = value.location.y / size.height - currentH / 2
        selectionRect.origin = CGPoint(x: max(0, min(1 - currentW, newX)), y: max(0, min(1 - currentH, newY)))
    }
    
    private func updateRect(corner: Corner, location: CGPoint, size: CGSize) {
        let nLoc = CGPoint(x: location.x / size.width, y: location.y / size.height)
        var r = selectionRect
        let minS: CGFloat = 0.05
        
        switch corner {
        case .topLeft:
            let newX = min(r.maxX - minS, max(0, nLoc.x))
            let newY = min(r.maxY - minS, max(0, nLoc.y))
            r = CGRect(x: newX, y: newY, width: r.maxX - newX, height: r.maxY - newY)
        case .topRight:
            let newMaxX = max(r.minX + minS, min(1, nLoc.x))
            let newY = min(r.maxY - minS, max(0, nLoc.y))
            r = CGRect(x: r.minX, y: newY, width: newMaxX - r.minX, height: r.maxY - newY)
        case .bottomLeft:
            let newX = min(r.maxX - minS, max(0, nLoc.x))
            let newMaxY = max(r.minY + minS, min(1, nLoc.y))
            r = CGRect(x: newX, y: r.minY, width: r.maxX - newX, height: newMaxY - r.minY)
        case .bottomRight:
            let newMaxX = max(r.minX + minS, min(1, nLoc.x))
            let newMaxY = max(r.minY + minS, min(1, nLoc.y))
            r = CGRect(x: r.minX, y: r.minY, width: newMaxX - r.minX, height: newMaxY - r.minY)
        }
        selectionRect = r
    }
    
    private func rectFromNormalized(_ norm: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: norm.minX * size.width, y: norm.minY * size.height, width: norm.width * size.width, height: norm.height * size.height)
    }
    
    private func cropImage(_ original: UIImage, normalizedRect: CGRect, viewSize: CGSize) -> UIImage {
        let imageRatio = original.size.width / original.size.height
        let viewRatio = viewSize.width / viewSize.height
        var renderRect = CGRect.zero
        
        if imageRatio > viewRatio {
            let scale = viewSize.width / original.size.width
            let height = original.size.height * scale
            renderRect = CGRect(x: 0, y: (viewSize.height - height) / 2, width: viewSize.width, height: height)
        } else {
            let scale = viewSize.height / original.size.height
            let width = original.size.width * scale
            renderRect = CGRect(x: (viewSize.width - width) / 2, y: 0, width: width, height: viewSize.height)
        }
        
        let selectionInView = rectFromNormalized(normalizedRect, in: viewSize)
        let intersection = selectionInView.intersection(renderRect)
        let scaleX = original.size.width / renderRect.width
        let scaleY = original.size.height / renderRect.height
        
        let cropRect = CGRect(
            x: (intersection.minX - renderRect.minX) * scaleX,
            y: (intersection.minY - renderRect.minY) * scaleY,
            width: intersection.width * scaleX,
            height: intersection.height * scaleY
        )
        
        if let cgImage = original.cgImage?.cropping(to: cropRect) {
            return UIImage(cgImage: cgImage, scale: original.scale, orientation: original.imageOrientation)
        }
        return original
    }
}

// MARK: - Selection Helpers

struct ResizeHandle: View {
    let at: CGPoint
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 32, height: 32)
            .shadow(radius: 2)
            .position(at)
    }
}

struct SelectionOverlayShape: Shape {
    var selectionRect: CGRect
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRect(selectionRect)
        return path
    }
}
