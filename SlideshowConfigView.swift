import SwiftUI
import SwiftData

struct SlideshowConfigView: View {
    @Query private var allKits: [Kit]
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Configuration State
    @State private var selectedCategory: iPadContentView.SidebarItem = .all
    @State private var isRandom: Bool = false
    @State private var showPlayer: Bool = false
    
    // Filtered Kits for Preview
    var targetKits: [Kit] {
        switch selectedCategory {
        case .all: return allKits
        case .slideshow: return [] // Should not happen in logical selection
        default:
            guard let status = selectedCategory.statusValue else { return [] }
            return allKits.filter { $0.statusValue == status }
        }
    }
    
    var body: some View {
        ZStack {
            // Glassmorphic Background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "play.rectangle.on.rectangle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                        .shadow(color: themeManager.currentTheme.mainColor.opacity(0.5), radius: 10)
                    
                    Text("スライドショー設定")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                .padding(.top, 40)
                
                // Configuration Controls
                HStack(spacing: 50) {
                    // Category Selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("対象")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        
                        Picker("Category", selection: $selectedCategory) {
                             Text("すべて").tag(iPadContentView.SidebarItem.all)
                             Text("完了済み").tag(iPadContentView.SidebarItem.complete)
                             Text("制作中").tag(iPadContentView.SidebarItem.inProgress)
                             Text("積みプラ").tag(iPadContentView.SidebarItem.stock)
                             Text("予約済み").tag(iPadContentView.SidebarItem.reservation)
                             Text("欲しいもの").tag(iPadContentView.SidebarItem.wish)
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 250, height: 120)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(12)
                    }
                    
                    // Mode Selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("再生モード")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        
                        VStack(spacing: 0) {
                            ToggleBtn(title: "順番", icon: "arrow.right", isSelected: !isRandom) {
                                withAnimation { isRandom = false }
                            }
                            Divider()
                            ToggleBtn(title: "ランダム", icon: "shuffle", isSelected: isRandom) {
                                withAnimation { isRandom = true }
                            }
                        }
                        .frame(width: 250)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(12)
                    }
                }
                
                // Info Display
                VStack(spacing: 5) {
                    Text("再生対象: \(targetKits.count)件")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(targetKits.isEmpty ? .red : .primary)
                    
                    if targetKits.isEmpty {
                        Text("選択されたカテゴリにデータがありません")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }
                .padding()
                
                // Launch Button
                Button(action: {
                    showPlayer = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                        Text("再生開始")
                    }
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 40)
                    .background(
                        Capsule()
                            .fill(targetKits.isEmpty ? Color.gray : themeManager.currentTheme.mainColor)
                    )
                    .shadow(color: (targetKits.isEmpty ? Color.clear : themeManager.currentTheme.mainColor.opacity(0.5)), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
                .disabled(targetKits.isEmpty)
                
                Spacer()
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showPlayer) {
            SlideshowPlayerView(kits: targetKits, isRandom: isRandom, isPresented: $showPlayer)
        }
    }
}

// Custom Toggle Button Helper
fileprivate struct ToggleBtn: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? themeManager.currentTheme.mainColor : .secondary)
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(isSelected ? themeManager.currentTheme.mainColor : .primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? themeManager.currentTheme.mainColor.opacity(0.1) : Color.clear)
    }
}
