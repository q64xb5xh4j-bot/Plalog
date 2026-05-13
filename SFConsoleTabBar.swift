import SwiftUI

struct SFConsoleTabBar: View {
    @Binding var selectedTab: Int
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 0) {
            // Tab 0: HANGAR
            consoleTab(
                index: 0,
                icon: "square.grid.2x2",
                label: "HANGAR"
            )
            
            // Spacer for style
            Spacer()
                .frame(width: 40)
            
            // Tab 1: BRIDGE
            consoleTab(
                index: 1,
                icon: "person.crop.square.filled.and.at.rectangle",
                label: "BRIDGE"
            )
        }
        .padding(8)
        .background(
            ZStack {
                // Glassy Background
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                // Tech Outline
                RoundedRectangle(cornerRadius: 30)
                    .stroke(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.mainColor.opacity(0.1),
                                themeManager.currentTheme.mainColor.opacity(0.8),
                                themeManager.currentTheme.mainColor.opacity(0.1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .cornerRadius(30)
        .padding(.horizontal, 40)
        .padding(.bottom, 20) // Floating from bottom
        .shadow(color: themeManager.currentTheme.mainColor.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    private func consoleTab(index: Int, icon: String, label: String) -> some View {
        let isSelected = selectedTab == index
        
        return Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                // Indicator Light
                Rectangle()
                    .fill(isSelected ? themeManager.currentTheme.mainColor : Color.clear)
                    .frame(width: 20, height: 2)
                    .shadow(color: themeManager.currentTheme.mainColor, radius: 2)
                
                Image(systemName: isSelected ? icon + ".fill" : icon)
                    .font(.system(size: 20))
                
                Text(label)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1)
            }
            .foregroundStyle(isSelected ? themeManager.currentTheme.mainColor : .gray)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .contentShape(Rectangle()) // Hit Area
        }
    }
}
