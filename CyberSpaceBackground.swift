import SwiftUI

struct CyberSpaceBackground: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var phase: CGFloat = 0
    
    var body: some View {
        ZStack {
            // 1. Adaptive Background
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            // 2. Horizon Glow
            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        themeManager.currentTheme.mainColor.opacity(0.0),
                        themeManager.currentTheme.mainColor.opacity(0.15),
                        themeManager.currentTheme.mainColor.opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 300)
            }
            .ignoresSafeArea()
            
            // 3. Cyber Grid (Perspective)
            GeometryReader { geo in
                Path { path in
                    let width = geo.size.width
                    let height = geo.size.height
                    
                    // Vertical Lines (Perspective)
                    for i in 0...20 {
                        let x = width / 20 * CGFloat(i)
                        // Make lines converge slightly towards top center to fake perspective
                        let xTop = (width / 2) + (x - width / 2) * 0.1
                        
                        path.move(to: CGPoint(x: xTop, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    
                    // Horizontal Lines (Scanning down)
                    for i in 0...10 {
                        // Exponential spacing for perspective
                        let y = height * pow(CGFloat(i) / 10.0, 2)
                        let yOffset = (y + phase * height) .truncatingRemainder(dividingBy: height)
                         
                        path.move(to: CGPoint(x: 0, y: yOffset))
                        path.addLine(to: CGPoint(x: width, y: yOffset))
                    }
                }
                .stroke(themeManager.currentTheme.mainColor.opacity(0.15), lineWidth: 1)
            }
            .onAppear {
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            
            // 4. Floating Particles (Noise)
            GeometryReader { geo in
                ForEach(0..<15) { i in
                    Circle()
                        .fill(themeManager.currentTheme.mainColor.opacity(0.2))
                        .frame(width: CGFloat.random(in: 2...4))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                }
            }
        }
    }
}
