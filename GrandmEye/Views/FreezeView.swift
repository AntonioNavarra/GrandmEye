import SwiftUI

/// A view that displays a frozen image with support for panning (pan).
/// Zoom is controlled externally via the main UI buttons.
struct FreezeView: View {
    // MARK: - Properties
    let image: UIImage
    @Binding var zoomFactor: CGFloat
    var onUnfreeze: () -> Void
    var onSave: () -> Void
    
    // States for image panning when magnified
    @State private var currentOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    
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
                
                // Status Badge (FROZEN)
                VStack {
                    HStack {
                        Text("ui_frozen") // Key from Localizable.xcstrings
                            .font(.system(size: 14, weight: .black))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.yellow)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                            .shadow(radius: 4)
                        
                        Spacer()
                    }
                    .padding(.top, 50)
                    .padding(.horizontal)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Logic
    
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
