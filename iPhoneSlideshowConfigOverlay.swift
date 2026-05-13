import SwiftUI
import SwiftData

struct iPhoneSlideshowConfigOverlay: View {
    @Binding var isPresented: Bool
    @Query private var allKits: [Kit]
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Enum matching iPad Sidebar logic but simplified for iPhone selector
    enum SlideshowCategory: String, CaseIterable, Identifiable {
        case all = "ALL UNITS"
        case complete = "COMPLETED"
        case inProgress = "CONSTRUCTING"
        case stock = "STOCKPILE"
        case reservation = "RESERVED"
        case wish = "WISH LIST"
        var id: String { rawValue }
        
        var statusValue: Int? {
            switch self {
            case .wish: return 0
            case .reservation: return 1
            case .stock: return 2
            case .inProgress: return 3
            case .complete: return 4
            default: return nil
            }
        }
        var localizedLabel: String {
            switch self {
            case .all: return "全キット"
            case .complete: return "完成"
            case .inProgress: return "製作中"
            case .stock: return "積み"
            case .reservation: return "予約済"
            case .wish: return "欲しい"
            }
        }
    }
    
    @State private var selectedCategory: SlideshowCategory = .all
    @State private var isRandom: Bool = false
    @State private var showPlayer: Bool = false
    
    var targetKits: [Kit] {
        switch selectedCategory {
        case .all: return allKits
        default:
            guard let status = selectedCategory.statusValue else { return [] }
            return allKits.filter { $0.statusValue == status }
        }
    }
    
    var body: some View {
        ZStack {
            // Dim Background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { isPresented = false } }
            
            // Modal Content
                VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 24) {
                    // Header with Close Button
                    ZStack {
                        Text("スライドショー")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                        
                        HStack {
                            Spacer()
                            Button {
                                LocalHaptics.tap()
                                withAnimation { isPresented = false }
                            } label: {
                                ZStack {
                                    Color.clear.frame(width: 60, height: 60) // Hit Area Expansion
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(themeManager.currentTheme.mainColor)
                                        .frame(width: 44, height: 44)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .clipShape(Circle())
                                }
                                .contentShape(Rectangle())
                            }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal)
                    
                    // Controls
                    VStack(spacing: 20) {
                        // Category
                        VStack(alignment: .leading, spacing: 8) {
                            Text("対象").font(.caption).foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(SlideshowCategory.allCases) { cat in
                                        Button(action: {
                                            LocalHaptics.select()
                                            selectedCategory = cat
                                        }) {
                                            Text(cat.localizedLabel)
                                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .foregroundStyle(selectedCategory == cat ? .white : .primary)
                                                .background(
                                                    Capsule()
                                                        .fill(selectedCategory == cat ? themeManager.currentTheme.mainColor : Color(UIColor.secondarySystemBackground))
                                                )
                                                .overlay(
                                                    Capsule()
                                                        .strokeBorder(themeManager.currentTheme.mainColor.opacity(0.3), lineWidth: selectedCategory == cat ? 0 : 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .frame(height: 50)
                        }
                        
                        // Mode
                        VStack(alignment: .leading, spacing: 8) {
                            Text("再生モード").font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 0) {
                                ToggleBtn(title: "順番", icon: "arrow.right", isSelected: !isRandom) {
                                    isRandom = false
                                }
                                Divider().frame(height: 20)
                                ToggleBtn(title: "ランダム", icon: "shuffle", isSelected: isRandom) {
                                    isRandom = true
                                }
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Start Button
                    Button(action: {
                        showPlayer = true
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("再生開始 (\(targetKits.count))")
                        }
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(targetKits.isEmpty ? Color.gray : themeManager.currentTheme.mainColor)
                        )
                        .shadow(color: themeManager.currentTheme.mainColor.opacity(0.4), radius: 8, y: 4)
                    }
                    .disabled(targetKits.isEmpty)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                    
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(24, corners: [.topLeft, .topRight])
            }
            .transition(.move(edge: .bottom))
        }
        .fullScreenCover(isPresented: $showPlayer) {
            SlideshowPlayerView(kits: targetKits, isRandom: isRandom, isPresented: $showPlayer)
        }
    }
}

fileprivate struct ToggleBtn: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: {
            LocalHaptics.select()
            action()
        }) {
            HStack {
                Spacer()
                Image(systemName: icon)
                Text(title).font(.system(size: 12, weight: .bold))
                Spacer()
            }
            .padding(.vertical, 14)
            .foregroundStyle(isSelected ? .white : .secondary) // Invert text color
            .background(isSelected ? themeManager.currentTheme.mainColor : Color.clear) // Solid background
        }
    }
}


