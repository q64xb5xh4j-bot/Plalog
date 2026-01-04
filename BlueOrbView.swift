import SwiftUI

/// Blue orb visual used across launch/home states.
/// - Note: This file must ONLY define `BlueOrbView` (avoid redeclaration errors).
struct BlueOrbView: View {
    let isAnimating: Bool
    let size: CGFloat

    // ✅ ThemeManager を監視してテーマ色を取得
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var breathing: Bool = false

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        // ✅ Color.blue を現在のテーマのメインカラーに置き換え
                        themeManager.currentTheme.mainColor.opacity(0.90),
                        themeManager.currentTheme.mainColor.opacity(0.60),
                        themeManager.currentTheme.mainColor.opacity(0.30)
                    ]),
                    center: .center,
                    startRadius: 5,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .scaleEffect(breathing ? 1.05 : 1.0)
            .opacity(breathing ? 0.90 : 1.0)
            .onAppear {
                syncBreathing(to: isAnimating)
            }
            // iOS 17+ signature (avoids deprecated warning)
            .onChange(of: isAnimating) { _, newValue in
                syncBreathing(to: newValue)
            }
    }

    @MainActor
    private func syncBreathing(to enabled: Bool) {
        if enabled {
            startBreathing()
        } else {
            // Stop breathing cleanly.
            breathing = false
        }
    }

    @MainActor
    private func startBreathing() {
        guard breathing == false else { return }
        withAnimation(
            .easeInOut(duration: 2.4)
            .repeatForever(autoreverses: true)
        ) {
            breathing = true
        }
    }
}
