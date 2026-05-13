import SwiftUI
import SwiftData

struct BridgeContent: View {
    // Configuration
    var showBackButton: Bool = false
    var onDismiss: (() -> Void)? = nil
    var onSettingsTap: (() -> Void)? = nil
    var onSlideshowTap: (() -> Void)? = nil
    
    // Feature States
    @State private var showStats: Bool = false
    @State private var showSync: Bool = false
    @State private var showSettings: Bool = false
    @State private var showSlideshow: Bool = false
    
    // Data
    @Query private var allKits: [Kit]
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var langManager = LanguageManager.shared
    
    @Environment(\.colorScheme) var colorScheme
    
    // Computed Stats
    var completedCount: Int { allKits.filter { $0.statusValue == 4 }.count }
    var stockCount: Int { allKits.filter { $0.statusValue == 2 }.count }
    var constructingCount: Int { allKits.filter { $0.statusValue == 3 }.count }
    var totalOwned: Int { allKits.filter { $0.statusValue != 0 }.count }
    
    // Avatar
    @State private var avatarImage: UIImage? = nil
    
    // Pilot Name
    @AppStorage("pilotName") private var pilotName: String = "COMMANDER"
    
    var body: some View {
        ZStack {
            // Background adaptation handled by parent or transparent
            if colorScheme == .light {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            }
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header / Pilot Info
                    VStack(spacing: 12) {
                        // Optional Back Button
                        if showBackButton {
                            HStack {
                                Button {
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                    onDismiss?()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "chevron.backward")
                                        Text("BACK TO HANGAR")
                                    }
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(themeManager.currentTheme.mainColor.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background {
                                        themeManager.currentTheme.mainColor.opacity(0.1)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(themeManager.currentTheme.mainColor.opacity(0.5), lineWidth: 1)
                                    )
                                    .cornerRadius(4)
                                }
                                Spacer()
                            }
                        }
                        
                        HStack {
                            Text("\(pilotName)")
                                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(.primary) // Adaptive color
                            
                            Spacer()
                            
                            // Avatar Circle
                            ZStack {
                                Circle().stroke(themeManager.currentTheme.mainColor, lineWidth: 2)
                                    .frame(width: 50, height: 50)
                                
                                if let img = avatarImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 46, height: 46)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(themeManager.currentTheme.mainColor)
                                }
                            }
                            .shadow(color: themeManager.currentTheme.mainColor, radius: 5)
                        }
                    }
                    .padding(.top, showBackButton ? 20 : 40) // Adjust padding based on back button
                    
                    // Holographic Stats Panel
                    HStack(spacing: 0) {
                        holoStatItem(label: langManager.t(.stats_logged), value: totalOwned)
                        
                        Divider().background(themeManager.currentTheme.mainColor.opacity(0.5))
                        
                        holoStatItem(label: langManager.t(.stats_stock), value: stockCount)
                        
                        Divider().background(themeManager.currentTheme.mainColor.opacity(0.5))
                        
                        holoStatItem(label: langManager.t(.stats_const), value: constructingCount)
                        
                        Divider().background(themeManager.currentTheme.mainColor.opacity(0.5))
                        
                        holoStatItem(label: langManager.t(.stats_done), value: completedCount)
                    }
                    .frame(height: 80)
                    .background(
                        ZStack {
                            if colorScheme == .dark {
                                Color.black.opacity(0.6)
                            } else {
                                Color(UIColor.secondarySystemBackground)
                            }
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeManager.currentTheme.mainColor.opacity(0.5), lineWidth: 1)
                        }
                    )
                    .cornerRadius(12)
                    .shadow(color: colorScheme == .light ? Color.black.opacity(0.1) : .clear, radius: 5, x: 0, y: 2)
                    
                    // Menu Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        
                        // 1. Pilot Stats
                        HoloMenuCard(
                            icon: "chart.bar.doc.horizontal",
                            title: langManager.t(.cmd_status_title),
                            subtitle: langManager.t(.cmd_status_desc)
                        ) {
                            showStats = true
                        }
                        
                        // 2. P2P Sync
                        HoloMenuCard(
                            icon: "antenna.radiowaves.left.and.right",
                            title: langManager.t(.cmd_sync_title),
                            subtitle: langManager.t(.cmd_sync_desc)
                        ) {
                            showSync = true
                        }
                        
                        // 3. Slideshow
                        HoloMenuCard(
                            icon: "play.square.stack",
                            title: langManager.t(.cmd_slide_title),
                            subtitle: langManager.t(.cmd_slide_desc)
                        ) {
                            if let action = onSlideshowTap {
                                action()
                            } else {
                                showSlideshow = true
                            }
                        }
                        
                        // 4. Settings
                        HoloMenuCard(
                            icon: "gearshape.2",
                            title: langManager.t(.cmd_system_title),
                            subtitle: langManager.t(.cmd_system_desc)
                        ) {
                            if let action = onSettingsTap {
                                action()
                            } else {
                                showSettings = true
                            }
                        }
                        
                    }
                    
                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 24)
            }
        }
        // Sheets
        .sheet(isPresented: $showStats) {
            PilotStatsWrapper()
        }
        .sheet(isPresented: $showSync) {
            P2PSyncView(isPresented: $showSync)
        }
        .sheet(isPresented: $showSettings) {
            SettingsOverlay(isPresented: $showSettings)
        }
        .fullScreenCover(isPresented: $showSlideshow) {
            iPhoneSlideshowConfigOverlay(isPresented: $showSlideshow)
        }
        .onAppear {
            loadAvatar()
        }
    }
    
    private func loadAvatar() {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("pilot_avatar.png"),
           let data = try? Data(contentsOf: url) {
            avatarImage = UIImage(data: data)
        }
    }
    
    @ViewBuilder
    private func holoStatItem(label: String, value: Int) -> some View {
        VStack(spacing: 4) {
             Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary) // Adaptive
                .shadow(color: themeManager.currentTheme.mainColor.opacity(colorScheme == .dark ? 1.0 : 0.0), radius: 5)
            
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(themeManager.currentTheme.mainColor)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HoloMenuCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(themeManager.currentTheme.mainColor.opacity(0.5))
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary) // Adaptive
                    Text(subtitle)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary) // Adaptive
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(16)
            .frame(height: 140)
            .background(
                Group {
                    if colorScheme == .dark {
                        Color.black.opacity(0.6)
                    } else {
                        Color(UIColor.secondarySystemBackground)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [themeManager.currentTheme.mainColor.opacity(0.6), themeManager.currentTheme.mainColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .cornerRadius(12)
            .shadow(color: colorScheme == .light ? Color.black.opacity(0.1) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
