//
//  CommanderMenuView.swift
//  Plalog
//
//  Created by (User) on 2026/01/11.
//  Commander Menu: オーブ長押しで呼び出される統合メニュー
//


import SwiftUI
import SwiftData

struct CommanderMenuView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    
    // Feature States
    @State private var showStats: Bool = false
    @State private var showSync: Bool = false
    @State private var showSettings: Bool = false
    @State private var showSlideshow: Bool = false
    
    // ✅ Health Check State
    @State private var showHealthCheckAlert: Bool = false
    @State private var healthCheckMessage: String = ""
    @State private var pendingUpdates: [(Kit, CSVKitData)] = []
    
    // Data for Stats Preview
    @Query private var allKits: [Kit]
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var langManager = LanguageManager.shared
    
    // Computed Stats
    var completedCount: Int { allKits.filter { $0.statusValue == 4 }.count }
    var stockCount: Int { allKits.filter { $0.statusValue == 2 }.count }
    var constructingCount: Int { allKits.filter { $0.statusValue == 3 }.count }
    var totalOwned: Int { allKits.filter { $0.statusValue != 0 }.count }
    
    // Avatar
    @State private var avatarImage: UIImage? = nil
    
    // Pilot Name
    @AppStorage("pilotName") private var pilotName: String = "COMMANDER"
    
    // Haptics
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        ZStack {
            // 1. Blurred Background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    closeMenu()
                }
            
            GeometryReader { geo in
                let isLandscape = geo.size.width > geo.size.height
                
                ScrollView {
                    VStack(spacing: isLandscape ? 15 : 30) {
                        // Header
                        Text("\(pilotName)\(langManager.t(.cmd_title))")
                            .font(.system(size: 24, weight: .heavy, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(themeManager.currentTheme.mainColor)
                            .padding(.top, isLandscape ? 20 : 60)
                        
                        // Quick Stats
                        HStack(spacing: 0) {
                            statItem(label: langManager.t(.stats_logged), value: totalOwned)
                            statItem(label: langManager.t(.stats_stock), value: stockCount)
                            statItem(label: langManager.t(.stats_const), value: constructingCount)
                            statItem(label: langManager.t(.stats_done), value: completedCount)
                        }
                        .padding(.vertical, 10)
                        .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                        .cornerRadius(12)
                        .padding(.horizontal, 30)
                        
                        // Grid of Features
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: isLandscape ? 4 : 2), spacing: 20) {
                            
                            // 1. Pilot Stats
                            FeatureCard(
                                icon: "person.crop.circle.badge.checkmark",
                                title: langManager.t(.cmd_status_title),
                                subtitle: langManager.t(.cmd_status_desc),
                                color: themeManager.currentTheme.mainColor,
                                image: avatarImage
                            ) {
                                showStats = true
                            }
                            
                            // 2. P2P Sync
                            FeatureCard(
                                icon: "antenna.radiowaves.left.and.right",
                                title: langManager.t(.cmd_sync_title),
                                subtitle: langManager.t(.cmd_sync_desc),
                                color: .blue
                            ) {
                                showSync = true
                            }
                            
                            // 3. Slideshow
                            FeatureCard(
                                icon: "play.rectangle.fill",
                                title: langManager.t(.cmd_slide_title),
                                subtitle: langManager.t(.cmd_slide_desc),
                                color: .orange
                            ) {
                                showSlideshow = true
                            }
                            
                            // 4. Settings
                            FeatureCard(
                                icon: "gearshape.fill",
                                title: langManager.t(.cmd_system_title),
                                subtitle: langManager.t(.cmd_system_desc),
                                color: .gray
                            ) {
                                showSettings = true
                            }
                            
                            // 5. DB Health Check
                            FeatureCard(
                                icon: "arrow.triangle.2.circlepath.circle.fill",
                                title: "DB HEALTH",
                                subtitle: "データの整合性を確認",
                                color: .green
                            ) {
                                performHealthCheck()
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        if !isLandscape {
                            Spacer()
                            
                            // Footer / Close Guide
                            VStack(spacing: 8) {
                                Button {
                                    closeMenu()
                                } label: {
                                    BlueOrbView(isAnimating: false, size: 60)
                                        .shadow(color: themeManager.currentTheme.mainColor.opacity(0.5), radius: 10, x: 0, y: 0)
                                        .overlay(
                                            Image(systemName: "xmark")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundStyle(.white.opacity(0.8))
                                        )
                                }
                                .buttonStyle(ScaleButtonStyle())
                                
                                Text(langManager.t(.cmd_close_guide))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.bottom, 40)
                        } else {
                            // Landscape Footer spacer
                            Spacer().frame(height: 20)
                        }
                    }
                    .frame(minHeight: geo.size.height)
                }
                .scrollIndicators(.hidden)
            }
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .sheet(isPresented: $showStats) {
            // Re-use existing PilotStatsOverlay but wrap/adapt if needed
            // PilotStatsOverlay requires Binding<UIImage?> for profile, let's load it here or pass separate
            PilotStatsWrapper()
        }
        .sheet(isPresented: $showSync) {
            P2PSyncView(isPresented: $showSync)
        }
        .sheet(isPresented: $showSettings) {
            SettingsOverlay(isPresented: $showSettings)
        }
        // ✅ Health Check Alert
        .alert("データベース整合性チェック", isPresented: $showHealthCheckAlert) {
            if !pendingUpdates.isEmpty {
                Button("すべて更新 (\(pendingUpdates.count)件)", role: .destructive) {
                    confirmUpdates()
                }
                Button("キャンセル", role: .cancel) { }
            } else {
                Button("OK", role: .cancel) { }
            }
        } message: {
            Text(healthCheckMessage)
        }

        // Slideshow uses a specific overlay, usually FullScreen
        .fullScreenCover(isPresented: $showSlideshow) {
            iPhoneSlideshowConfigOverlay(isPresented: $showSlideshow)
        }
        .onAppear {
            impact.prepare()
            impact.impactOccurred()
            loadMenuAvatar()
        }
    }
    
    private func loadMenuAvatar() {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("pilot_avatar.png"),
           let data = try? Data(contentsOf: url) {
            avatarImage = UIImage(data: data)
        }
    }
    
    private func closeMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
    
    // ✅ Health Check Logic
    private func performHealthCheck() {
        let updates = CSVDataManager.shared.checkForUpdates(for: allKits)
        pendingUpdates = updates
        
        if updates.isEmpty {
            healthCheckMessage = "データベースとの差異は見つかりませんでした。\nすべてのデータは最新です。"
        } else {
            healthCheckMessage = "\(updates.count)件のデータ更新が見つかりました。\n（JANコードに基づく情報の修正）\n\n最新のデータベースに合わせてタイトルや詳細を更新しますか？"
        }
        
        showHealthCheckAlert = true
    }
    
    private func confirmUpdates() {
        var count = 0
        for (kit, match) in pendingUpdates {
            kit.title = match.title
            kit.maker = match.maker
            kit.series = match.series
            kit.grade = match.grade
            kit.scale = match.scale
            // jan is already same
            kit.updatedDate = Date()
            count += 1
        }
        
        try? modelContext.save()
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        
        // Reset
        pendingUpdates = []
    }

    
    @ViewBuilder
    func statItem(label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// Helper Card
struct FeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var image: UIImage? = nil // Optional Image Support
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(spacing: 15) {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(color.opacity(0.5), lineWidth: 2))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 30))
                        .foregroundStyle(color)
                        .frame(width: 60, height: 60)
                        .background(color.opacity(0.1))
                        .clipShape(Circle())
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 25)
            .background(Color(UIColor.secondarySystemBackground).opacity(0.8))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}



// Wrapper for PilotStats to handle avatar loading locally
struct PilotStatsWrapper: View {
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Kit.createdDate, order: .reverse) private var allKits: [Kit]
    @State private var profileImage: UIImage? = nil
    @State private var isPresented = true // Dummy binding
    
    var body: some View {
        PilotStatsOverlay(allKits: allKits, isPresented: $isPresented, profileImage: $profileImage)
            .task {
                loadAvatar()
            }
            .onChange(of: isPresented) { _, newValue in
                if !newValue { dismiss() }
            }
    }
    
    private func loadAvatar() {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("pilot_avatar.png"),
           let data = try? Data(contentsOf: url) {
            profileImage = UIImage(data: data)
        }
    }
}
