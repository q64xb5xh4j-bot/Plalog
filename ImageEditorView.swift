
import SwiftUI

struct ImageEditorView: View {
    let image: UIImage
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotation: Double = 0.0
    
    @State private var viewSize: CGSize = .zero
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Config
    private let maskAspectRatio: CGFloat = 1.33 // 4:3ish
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                    }
                    Spacer()
                    Text("調整")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: {
                        if let cropped = cropImage() {
                            onComplete(cropped)
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
                        // Image Layer
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .rotationEffect(.degrees(rotation))
                            .offset(offset)
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { val in
                                            let delta = val / lastScale
                                            lastScale = val
                                            scale *= delta
                                        }
                                        .onEnded { _ in lastScale = 1.0 },
                                    DragGesture()
                                        .onChanged { val in
                                            offset = CGSize(
                                                width: lastOffset.width + val.translation.width,
                                                height: lastOffset.height + val.translation.height
                                            )
                                        }
                                        .onEnded { _ in lastOffset = offset }
                                )
                            )
                            
                        // Mask Layer (Inverse)
                        // Actually, we just need a border overlay to indicate what will be captured.
                        // The render logic is what matters.
                        Rectangle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: geo.size.width - 40, height: (geo.size.width - 40) / maskAspectRatio)
                            .shadow(color: .black, radius: 2)
                            .allowsHitTesting(false) // Pass touches to image
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .onAppear {
                        viewSize = geo.size
                    }
                    .onChange(of: geo.size) { newSize in
                        viewSize = newSize
                    }
                }
                .frame(maxHeight: 500)
                
                Spacer()
                
                // Footer Controls
                VStack(spacing: 20) {
                    HStack {
                         Image(systemName: "rotate.left").foregroundStyle(.secondary)
                         Slider(value: $rotation, in: -45...45)
                         Image(systemName: "rotate.right").foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 40)
                    
                    HStack(spacing: 40) {
                         Button(action: { rotate90(left: true) }) {
                             VStack {
                                 Image(systemName: "rotate.left.fill").font(.title2)
                                 Text("-90°").font(.caption)
                             }.foregroundStyle(.white)
                         }
                         Button(action: { rotate90(left: false) }) {
                             VStack {
                                 Image(systemName: "rotate.right.fill").font(.title2)
                                 Text("+90°").font(.caption)
                             }.foregroundStyle(.white)
                         }
                    }
                }
                .padding(.bottom, 20)
                .background(Color.black.opacity(0.8))
            }
        }
    }
    
    private func rotate90(left: Bool) {
        withAnimation {
            rotation += left ? -90 : 90
        }
    }
    
    @MainActor
    private func cropImage() -> UIImage? {
        print("ImageEditor: Starting crop. viewSize: \(viewSize), scale: \(scale), offset: \(offset), rotation: \(rotation)")
        // Fallback size if viewSize is invalid (Root Cause Fix: Never allow 0 size)
        var renderSize = viewSize
        if renderSize.width <= 0 {
            renderSize = UIScreen.main.bounds.size
        }
        
        let targetWidth = renderSize.width - 40
        // Safety check for ridiculous values
        guard targetWidth > 10 else { return image } // Return original if too small? No, return something.
        
        let targetHeight = targetWidth / maskAspectRatio
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        
        // Use UIGraphicsImageRenderer with Screen Scale for quality
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        
        return renderer.image { context in
            // 1. Fill Background
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            
            // 2. Setup Context Transforms (Center Origin)
            let c = context.cgContext
            c.translateBy(x: targetSize.width / 2, y: targetSize.height / 2)
            
            // 3. Apply User Transforms
            // Matches SwiftUI: Offset -> Rotation -> Scale (Calculated relative to center)
            c.translateBy(x: offset.width, y: offset.height)
            c.rotate(by: rotation * .pi / 180)
            c.scaleBy(x: scale, y: scale)
            
            // 4. Calculate Draw Rect (Match SwiftUI .scaledToFit in viewSize)
            // The UI displays the image fitted to 'viewSize' (Screen/Container), NOT 'targetSize' (Mask).
            // We must replicate that base size.
            let imageSize = image.size
            let aspectRatio = imageSize.width / imageSize.height
            let screenRatio = viewSize.width / viewSize.height
            
            var baseDrawSize = CGSize.zero
            if aspectRatio > screenRatio {
                // Image is wider than screen -> fit width of screen
                baseDrawSize.width = viewSize.width
                baseDrawSize.height = viewSize.width / aspectRatio
            } else {
                // Image is taller -> fit height of screen
                baseDrawSize.width = viewSize.height * aspectRatio
                baseDrawSize.height = viewSize.height
            }
            
            let drawRect = CGRect(
                x: -baseDrawSize.width / 2,
                y: -baseDrawSize.height / 2,
                width: baseDrawSize.width,
                height: baseDrawSize.height
            )
            
            image.draw(in: drawRect)
        }
    }
}
