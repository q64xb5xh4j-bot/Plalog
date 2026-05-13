import SwiftUI
import Combine

struct SlideshowPlayerView: View {
    let kits: [Kit]
    let isRandom: Bool
    @Binding var isPresented: Bool
    
    @State private var currentIndex: Int = 0
    @State private var displayKits: [Kit] = []
    @State private var isPlaying: Bool = true
    @State private var showControls: Bool = false
    @State private var showSubtitle: Bool = false // ✅ Added State
    
    // Animation States
    @State private var mainID: UUID = UUID()
    @State private var mainScale: CGFloat = 0.0
    @State private var mainOpacity: Double = 0.0
    @State private var mainOffset: CGSize = .zero // Current Offset
    @State private var startOffset: CGSize = .zero // Where it comes from
    
    // Ambient Background Data
    @State private var ambientKits: [AmbientKit] = []
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Timer for the animation cycle
    @State private var stepTimer: AnyCancellable?
    @State private var animationPhase: AnimationPhase = .idle
    
    enum AnimationPhase {
        case idle
        case zoomingIn
        case holding
        case zoomingOut
    }
    
    struct AmbientKit: Identifiable {
        let id = UUID()
        let kit: Kit
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat
        var opacity: Double
        var speed: Double // Fall duration
    }
    
    var body: some View {
        ZStack {
            // 1. Endless Void Background (Adaptive)
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            // Grid Overlay for Cyber effect
            CyberGridBackground()
                .opacity(0.1)
            
            // 2. Ambient Layer (Falling Matrix Effect)
            GeometryReader { geo in
                ZStack {
                     // Use fallback if geo is empty (iPhone startup fix)
                     let width = geo.size.width > 0 ? geo.size.width : UIScreen.main.bounds.width
                     let height = geo.size.height > 0 ? geo.size.height : UIScreen.main.bounds.height
                     
                     ForEach(ambientKits) { item in
                         AmbientFallingUnit(
                             kit: item.kit,
                             screenWidth: width,
                             screenHeight: height,
                             xRate: item.x,
                             speed: item.speed,
                             scale: item.scale,
                             opacity: item.opacity
                         )
                     }
                }
            }
            .ignoresSafeArea()
            
            // 3. Focus Layer (Main Animation)
            if !displayKits.isEmpty {
                GeometryReader { mainGeo in
                    VStack {
                        Spacer()
                        ImageView(kit: displayKits[currentIndex])
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(mainScale)
                            .opacity(mainOpacity)
                            .offset(mainOffset) // Actual movement
                            .id(mainID) // Force redraw on change
                            .shadow(color: themeManager.currentTheme.mainColor.opacity(0.5), radius: 20, x: 0, y: 0)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .onTapGesture {
                    withAnimation { showControls.toggle() }
                }
            } else {
                Text("NO DATA")
                    .font(.largeTitle)
                    .foregroundStyle(.gray)
            }
            
            // 4. Info Overlay (Synced with Main Unit)
            // Show during holding OR late zooming in
            if !displayKits.isEmpty && showSubtitle {
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayKits[currentIndex].title)
                                .font(.system(size: 24, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            
                            HStack(spacing: 8) {
                                // Status Icon (Correct Assets)
                                Group {
                                    if let icon = getStatusIcon(for: displayKits[currentIndex].statusValue) {
                                        Image(icon)
                                            .renderingMode(.template) // Ensure color tint works
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 16, height: 16)
                                            .foregroundStyle(themeManager.currentTheme.mainColor)
                                    }
                                }
                                
                                Text(displayKits[currentIndex].grade)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(themeManager.currentTheme.mainColor.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                                
                                Text(displayKits[currentIndex].scale)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.primary.opacity(0.2))
                                    .cornerRadius(4)
                                
                                Spacer()
                                
                                Text("Vis.ARCHIVE: \(currentIndex + 1) / \(displayKits.count)")
                                    .font(.monospacedDigit(.caption)())
                                    .foregroundStyle(.secondary)
                            }
                            .font(.system(size: 14, weight: .bold))
                        }
                        .padding(20)
                        .background(.thinMaterial)
                        .cornerRadius(12)
                        .padding(20)
                        
                        Spacer()
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut, value: showSubtitle)
            }
            
            // 5. Controls Overlay
            if showControls {
                VStack {
                    HStack {
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.primary.opacity(0.8))
                                .padding()
                        }
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Playback Controls
                    HStack(spacing: 40) {
                        Button(action: {
                            skipToPrevious()
                        }) {
                            Image(systemName: "backward.fill").font(.title)
                        }
                        
                        Button(action: {
                            togglePlayPause()
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 50))
                                .symbolEffect(.bounce, value: isPlaying)
                        }
                        
                        Button(action: {
                            skipToNext()
                        }) {
                            Image(systemName: "forward.fill").font(.title)
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding(.bottom, 50)
                    .background(.thinMaterial)
                    .cornerRadius(30)
                    .padding(.bottom, 50)
                }
                .zIndex(100)
            }
        }
        .onAppear {
            // Delay setup slightly to ensure GeometryReader has valid size
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                setupKits()
                startSequence()
            }
        }
        .onDisappear {
            stopSequence()
        }
    }
    
    // MARK: - Logic
    
    private func setupKits() {
        if isRandom {
            displayKits = kits.shuffled()
        } else {
            // Sort by Created Date Descending (Newest First)
            displayKits = kits.sorted(by: { $0.createdDate > $1.createdDate })
        }
        
        // Setup Ambient Background
        generateAmbientKits()
    }
    
    private func generateAmbientKits() {
        guard !displayKits.isEmpty else { return }
        // Generate more items for heavy rain effect
        ambientKits = (0..<20).map { _ in
            AmbientKit(
                kit: displayKits.randomElement()!,
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: -1...0), // Start above screen
                scale: CGFloat.random(in: 0.15...0.4),
                opacity: Double.random(in: 0.1...0.3),
                speed: Double.random(in: 10.0...25.0) // Fall duration (slower looks more massive, faster looks like rain)
            )
        }
    }
    
    private func startSequence() {
        guard isPlaying, !displayKits.isEmpty else { return }
        runAnimationCycle() // Start immediately
    }
    
    private func stopSequence() {
        stepTimer?.cancel()
        stepTimer = nil
    }
    
    private func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying {
            runAnimationCycle()
        } else {
            stopSequence()
        }
    }
    
    private func runAnimationCycle() {
        // 1. Reset State IMMEDIATELY (No Animation)
        let randomX = CGFloat.random(in: -150...150)
        let randomY = CGFloat.random(in: -150...150)
        startOffset = CGSize(width: randomX, height: randomY)
        
        mainOffset = startOffset
        mainScale = 0.01
        mainOpacity = 0.0
        showSubtitle = false
        animationPhase = .zoomingIn
        
        // 2. Trigger Animation AFTER Rendering Layout (Next RunLoop)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.triggerZoomIn()
        }
    }
    
    private func triggerZoomIn() {
        // Animate IN
        withAnimation(.easeIn(duration: 2.5)) {
            mainOffset = .zero
            mainScale = 1.0
        }
        
        // Opacity
        withAnimation(.linear(duration: 1.5)) {
            mainOpacity = 1.0
        }
        
        // Subtitle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if self.animationPhase == .zoomingIn {
                 withAnimation {
                     self.showSubtitle = true
                 }
            }
        }
        
        // Schedule HOLD
        stepTimer = Timer.publish(every: 2.5, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { _ in
                beginHold()
            }
    }
    
    private func beginHold() {
        animationPhase = .holding
        showSubtitle = true // Ensure it's on
        
        // 4. Schedule OUT
        // Hold for 5.0 seconds as requested
        stepTimer = Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { _ in
                beginZoomOut()
            }
    }
    
    private func beginZoomOut() {
        animationPhase = .zoomingOut
        showSubtitle = false // Fade out subtitle immediately
        
        // 5. Animate OUT (Fast return: 0.8s)
        // Geometry: Move and Scale 
        withAnimation(.easeIn(duration: 0.8)) {
            mainOffset = startOffset 
            mainScale = 0.0
        }
        
        // Opacity: Fade out ONLY at the very end (Delay 0.5s)
        withAnimation(.linear(duration: 0.3).delay(0.5)) {
            mainOpacity = 0.0
        }
        
        // 6. Schedule Next Cycle
        stepTimer = Timer.publish(every: 0.8, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { _ in
                advanceIndex()
                if isPlaying {
                    // Small pause before next one comes in?
                    runAnimationCycle()
                }
            }
    }
    
    private func advanceIndex() {
        currentIndex = (currentIndex + 1) % displayKits.count
        mainID = UUID() // Force view refresh
        animationPhase = .idle
    }
    
    private func skipToNext() {
        stopSequence()
        advanceIndex()
        if isPlaying { runAnimationCycle() }
    }
    
    private func skipToPrevious() {
        stopSequence()
        currentIndex = (currentIndex - 1 + displayKits.count) % displayKits.count
        mainID = UUID()
        if isPlaying { runAnimationCycle() }
    }
    
    private func getStatusIcon(for status: Int) -> String? {
        switch status {
        case 0: return "wish"
        case 1: return "reservation"
        case 2: return "stock"
        case 3: return "inprogress"
        case 4: return "complete"
        default: return nil
        }
    }
}

// MARK: - Subviews

struct AmbientFallingUnit: View {
    let kit: Kit
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let xRate: CGFloat
    let speed: Double
    let scale: CGFloat
    let opacity: Double
    
    @State private var offsetRate: CGFloat = -0.2 // Start slightly above
    @State private var isAnimating: Bool = false
    
    var body: some View {
        ImageView(kit: kit)
            .aspectRatio(contentMode: .fit)
            .frame(width: 200, height: 200)
            .scaleEffect(scale)
            .opacity(opacity)
            .blur(radius: 5)
            .position(x: xRate * screenWidth, y: offsetRate * screenHeight)
            .onAppear {
                isAnimating = true
            }
            .onChange(of: isAnimating) { _, newValue in
                if newValue {
                    // Force animation on main thread next cycle
                    DispatchQueue.main.async {
                        withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                            offsetRate = 1.2
                        }
                    }
                }
            }
    }
}

struct CyberGridBackground: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let width = geo.size.width
                let height = geo.size.height
                let spacing: CGFloat = 40
                
                for x in stride(from: 0, through: width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                
                for y in stride(from: 0, through: height, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        }
    }
}

// Helper for consistent image loading
fileprivate struct ImageView: View {
    let kit: Kit
    
    var body: some View {
        Group {
            let showCompleted = (kit.statusValue == 4 && kit.completedImageURLString != nil && !kit.completedImageURLString!.isEmpty)
            let targetURL = showCompleted ? kit.completedImageURLString : kit.imageURLString
            let targetData = showCompleted ? kit.completedImageData : kit.imageData
            
            UniversalImageView(imageData: targetData, imagePath: targetURL)
        }
    }
}
