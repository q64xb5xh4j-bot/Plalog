import SwiftUI
import Combine

struct MainTabView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showBridge: Bool = false // State to control Bridge view presentation
    
    var body: some View {
        ZStack {
            // Global Background
            CyberSpaceBackground()
                .zIndex(0)
            
            // Content Layer
            HangarView(showBridge: $showBridge)
                .zIndex(1)
            
            if showBridge {
                BridgeView(isPresented: $showBridge)
                    .zIndex(2)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
}
