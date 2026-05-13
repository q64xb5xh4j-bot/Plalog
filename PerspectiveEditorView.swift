
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct PerspectiveEditorView: View {
    let image: UIImage
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void
    
    // Selection State
    enum Corner { case topLeft, topRight, bottomLeft, bottomRight }
    @State private var selectedCorner: Corner? = nil

    // Geometry State
    @State private var topLeft: CGPoint = .zero
    @State private var topRight: CGPoint = .zero
    @State private var bottomLeft: CGPoint = .zero
    @State private var bottomRight: CGPoint = .zero
    
    // View State
    @State private var viewSize: CGSize = .zero
    @State private var imageFrame: CGRect = .zero
    @State private var isInitialized: Bool = false
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Header
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                    }
                    Spacer()
                    Text("パース補正")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: {
                        if let corrected = applyPerspectiveCorrection() {
                            onComplete(corrected)
                        }
                    }) {
                        Image(systemName: "checkmark")
                            .font(.title2)
                            .foregroundStyle(themeManager.currentTheme.mainColor)
                            .padding()
                    }
                }
                
                Spacer()
                
                // Editor Area
                GeometryReader { geo in
                    ZStack {
                        // Base Image
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .background(GeometryReader { imageGeo -> Color in
                                DispatchQueue.main.async {
                                    self.imageFrame = imageGeo.frame(in: .named("EditorSpace"))
                                    if !isInitialized {
                                        resetCorners(to: self.imageFrame)
                                        isInitialized = true
                                    }
                                }
                                return Color.clear
                            })
                            .id("BaseImage")
                        
                        // Overlay Layer
                        if isInitialized {
                            PerspectiveOverlay(
                                topLeft: $topLeft,
                                topRight: $topRight,
                                bottomLeft: $bottomLeft,
                                bottomRight: $bottomRight,
                                selectedCorner: $selectedCorner,
                                bounds: imageFrame
                            )
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .coordinateSpace(name: "EditorSpace")
                    .onAppear {viewSize = geo.size}
                    // Tap background to deselect
                    .onTapGesture { withAnimation { selectedCorner = nil } }
                }
                .padding()
                
                // Footer Controls (D-Pad)
                VStack(spacing: 12) {
                    if let _ = selectedCorner {
                        Text("十字キーで微調整")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        NudgeControls { dx, dy in
                            nudgeSelectedCorner(dx: dx, dy: dy)
                        }
                    } else {
                        Text("四隅の点をタップして選択")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.vertical, 20)
                        
                        Button("リセット") {
                            withAnimation { resetCorners(to: imageFrame) }
                        }
                        .foregroundColor(.white)
                    }
                }
                .frame(height: 140)
                .padding(.bottom, 20)
            }
        }
    }
    
    private func nudgeSelectedCorner(dx: CGFloat, dy: CGFloat) {
        let step: CGFloat = 2.0 // Pixel step per tap
        withAnimation(.linear(duration: 0.1)) {
            switch selectedCorner {
            case .topLeft: topLeft.x += dx * step; topLeft.y += dy * step
            case .topRight: topRight.x += dx * step; topRight.y += dy * step
            case .bottomLeft: bottomLeft.x += dx * step; bottomLeft.y += dy * step
            case .bottomRight: bottomRight.x += dx * step; bottomRight.y += dy * step
            case .none: break
            }
        }
    }
    
    private func resetCorners(to rect: CGRect) {
        let insetX = rect.width * 0.05
        let insetY = rect.height * 0.05
        topLeft = CGPoint(x: rect.minX + insetX, y: rect.minY + insetY)
        topRight = CGPoint(x: rect.maxX - insetX, y: rect.minY + insetY)
        bottomLeft = CGPoint(x: rect.minX + insetX, y: rect.maxY - insetY)
        bottomRight = CGPoint(x: rect.maxX - insetX, y: rect.maxY - insetY)
        selectedCorner = nil
    }
    
    private func applyPerspectiveCorrection() -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let normalize = { (p: CGPoint) -> CGPoint in
            let x = (p.x - imageFrame.minX) / imageFrame.width
            let y = (p.y - imageFrame.minY) / imageFrame.height
            return CGPoint(x: x, y: y)
        }
        
        // Convert to CI coordinates (Y is Up)
        let imageSize = image.size
        let toCI = { (p: CGPoint) -> CGPoint in
            let n = normalize(p)
            let x = n.x * imageSize.width
            let y = (1 - n.y) * imageSize.height
            return CGPoint(x: x, y: y)
        }
        
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = ciImage
        filter.topLeft = toCI(topLeft)
        filter.topRight = toCI(topRight)
        filter.bottomLeft = toCI(bottomLeft)
        filter.bottomRight = toCI(bottomRight)
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let context = CIContext()
        if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}

// MARK: - Subviews

struct PerspectiveOverlay: View {
    @Binding var topLeft: CGPoint
    @Binding var topRight: CGPoint
    @Binding var bottomLeft: CGPoint
    @Binding var bottomRight: CGPoint
    @Binding var selectedCorner: PerspectiveEditorView.Corner?
    let bounds: CGRect
    
    var body: some View {
        ZStack {
            // Path
            Path { path in
                path.move(to: topLeft)
                path.addLine(to: topRight)
                path.addLine(to: bottomRight)
                path.addLine(to: bottomLeft)
                path.closeSubpath()
            }
            .stroke(Color.white.opacity(0.8), lineWidth: 2)
            
            // Handles
            CornerHandle(position: $topLeft, isSelected: selectedCorner == .topLeft) { selectedCorner = .topLeft }
            CornerHandle(position: $topRight, isSelected: selectedCorner == .topRight) { selectedCorner = .topRight }
            CornerHandle(position: $bottomLeft, isSelected: selectedCorner == .bottomLeft) { selectedCorner = .bottomLeft }
            CornerHandle(position: $bottomRight, isSelected: selectedCorner == .bottomRight) { selectedCorner = .bottomRight }
        }
    }
}

struct CornerHandle: View {
    @Binding var position: CGPoint
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            // Transparent Hit Area
            Circle()
                .fill(Color.white.opacity(0.01))
                .frame(width: 44, height: 44) // Larger hit area
            
            // Outer Ring
            Circle()
                .stroke(isSelected ? ThemeManager.shared.currentTheme.mainColor : Color.white, lineWidth: 2)
                .frame(width: 30, height: 30)
                .shadow(color: .black.opacity(0.5), radius: 2)
            
            // Center Dot
            Circle()
                .fill(isSelected ? ThemeManager.shared.currentTheme.mainColor : Color.white)
                .frame(width: 6, height: 6)
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .position(position)
        .gesture(
            DragGesture()
                .onChanged { value in
                    self.position = value.location
                    self.onTap() // Select on drag start
                }
        )
        .onTapGesture { onTap() }
    }
}

struct NudgeControls: View {
    let onNudge: (CGFloat, CGFloat) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Up
            NudgeButton(icon: "chevron.up", dx: 0, dy: -1, action: onNudge)
            
            HStack(spacing: 24) {
                // Left
                NudgeButton(icon: "chevron.left", dx: -1, dy: 0, action: onNudge)
                
                // Center (Decoration)
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 20, height: 20)
                
                // Right
                NudgeButton(icon: "chevron.right", dx: 1, dy: 0, action: onNudge)
            }
            
            // Down
            NudgeButton(icon: "chevron.down", dx: 0, dy: 1, action: onNudge)
        }
    }
}

struct NudgeButton: View {
    let icon: String
    let dx: CGFloat
    let dy: CGFloat
    let action: (CGFloat, CGFloat) -> Void
    
    // Timer for hold-to-repeat
    @State private var timer: Timer?
    @State private var isHolding = false
    
    var body: some View {
        Image(systemName: icon)
            .font(.title2)
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(Color.white.opacity(0.15))
            .clipShape(Circle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isHolding {
                            isHolding = true
                            action(dx, dy) // Initial fire
                            // Start timer
                            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                                action(dx, dy)
                            }
                        }
                    }
                    .onEnded { _ in
                        isHolding = false
                        timer?.invalidate()
                        timer = nil
                    }
            )
    }
}
