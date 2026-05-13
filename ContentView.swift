// ContentView.swift V28
// 1. バージョン管理ルールに基づき更新 (V27 -> V28)
// 2. 修正点: 破損したファイル構造の修復とiPhoneスライドショーボタンの追加
// 3. 全文差し替えルール適用

import SwiftUI
import SwiftData
import Photos
import CoreMotion // ジャイロセンサー用
import UIKit      // UIColor用
import StoreKit   // 課金用
import Combine    // ObservableObject, @Published に必須

struct ContentView: View {
    @Query(sort: \Kit.createdDate, order: .reverse) private var allKits: [Kit]
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var storeManager = StoreKitManager.shared
    
    // ジャイロ管理マネージャー
    @StateObject private var motionManager = MotionManager()

    // MARK: - Phase & State
    private enum Phase { case launchHold, moving, home }
    @State private var phase: Phase = .launchHold
    @State private var progress: CGFloat = 0
    @State private var showMenu: Bool = false
    @State private var didStart: Bool = false
    
    @State private var showCommanderMenu: Bool = false
    
    // Legacy states (kept for compatibility if referenced, but unused in main view)
    @State private var showAddFlow: Bool = false
    @State private var editingKit: Kit? = nil
    
    // 課金画面用ステート
    @State private var showPurchaseOverlay: Bool = false
    @State private var bounceYOffset: CGFloat = 0

    enum MenuItem: String, Identifiable {
        case add, wish, reservation, stock, inprogress, complete
        var id: String { rawValue }
        var assetName: String { rawValue }
        
        var statusValue: Int? {
            switch self {
            case .wish: return 0
            case .reservation: return 1
            case .stock: return 2
            case .inprogress: return 3
            case .complete: return 4
            default: return nil
            }
        }
    }
    @State private var selected: MenuItem? = nil

    // MARK: - Constants
    private let launchHold: Double = 0.9
    private let moveDuration: Double = 1.8
    private let menuFadeDuration: Double = 0.3
    private let bounceHeight: CGFloat = 30
    private let bounceUp: Double = 0.1
    private let bounceDown: Double = 0.15
    private let bounceGap: Double = 0.02
    private let landingHapticAdvance: Double = 0.45
    private let orbSizeHome: CGFloat = 70
    private let orbSizeLaunchVisual: CGFloat = 240
    private var launchScale: CGFloat { orbSizeLaunchVisual / orbSizeHome }
    private let verticalSpacing: CGFloat = 12
    private let horizontalSpacing: CGFloat = 52
    private let iconSize: CGFloat = 60
    private let iconCornerRadius: CGFloat = 14
    private let iconInnerPadding: CGFloat = 12
    private let launchTopPadding: CGFloat = 70
    private let menuBottomOffsetPortrait: CGFloat = -50
    private let cardWidth: CGFloat = 220
    private let cardHeight: CGFloat = 320
    private let cardSpacing: CGFloat = 20
    private let carouselBottomSpacerPortrait: CGFloat = 200

    private var filteredKits: [Kit] {
        guard let s = selected, let val = s.statusValue else { return [] }
        return allKits.filter { $0.statusValue == val }
    }
    
    private var isLimitReached: Bool {
        if storeManager.isPremium { return false }
        return allKits.count >= 10
    }
    
    // 統計用カウント
    private var stockCount: Int { allKits.filter { $0.statusValue == 2 }.count }
    private var inProgressCount: Int { allKits.filter { $0.statusValue == 3 }.count }
    private var completeCount: Int { allKits.filter { $0.statusValue == 4 }.count }

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            // geo.safeAreaInsets は親がignoresSafeAreaしていない限り0になる可能性があるため
            // 以下のZStack内で明示的にignoresSafeAreaしている背景とは区別して、
            // コンテンツ配置用の「安全な枠」としてgeo.sizeを使用する
            
            let bottomSafeArea = geo.safeAreaInsets.bottom
            let topSafeArea = geo.safeAreaInsets.top
            
            ZStack {
                // Layer 0: Background
                ZStack {
                    Color(uiColor: .systemBackground).ignoresSafeArea()
                    
                    if let _ = selected, selected != .add {
                        // ジャイロパララックス適用
                        BackgroundWallView(kits: filteredKits)
                            .opacity(0.8)
                            .offset(x: motionManager.roll * 30, y: motionManager.pitch * 30)
                            .animation(.linear(duration: 0.1), value: motionManager.roll)
                            .transition(.opacity.animation(.easeInOut(duration: 0.8)))
                    }
                }
                .zIndex(0)

                // Layer 1: Main Content (Carousel, Menu, Orb)
                ZStack {
                    if let _ = selected, selected != .add {
                        VStack {
                            Spacer()
                            if filteredKits.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "cube.transparent")
                                        .font(.system(size: 50))
                                        .foregroundStyle(themeManager.currentTheme.mainColor.opacity(0.5))
                                    Text("No Items Here").font(.headline).foregroundStyle(.secondary)
                                }
                                .frame(height: 300)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: cardSpacing) {
                                        let sidePadding = (geo.size.width - cardWidth) / 2
                                        Spacer().frame(width: sidePadding)
                                        ForEach(filteredKits) { kit in
                                            GeometryReader { proxy in
                                                let midX = proxy.frame(in: .global).midX
                                                let distance = midX - geo.size.width / 2
                                                let rotation = Double(distance / (geo.size.width / 2)) * 20
                                                let scale = calculateScale(proxy: proxy, in: geo)
                                                KitCardView(kit: kit)
                                                    .scaleEffect(scale)
                                                    .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
                                                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 10)
                                                    .onTapGesture { Haptics.tap(); editingKit = kit }
                                            }
                                            .frame(width: cardWidth, height: cardHeight)
                                            .zIndex(-Double(kit.createdDate.timeIntervalSince1970))
                                        }
                                        Spacer().frame(width: sidePadding)
                                    }
                                    .padding(.vertical, 20)
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                            Spacer().frame(height: isLandscape ? 80 : carouselBottomSpacerPortrait)
                        }
                        .frame(maxHeight: geo.size.height)
                        .zIndex(1)
                    }

                    VStack {
                        Spacer()
                        if isLandscape {
                            HStack(spacing: 24) {
                                menuTile(.add); menuTile(.wish); menuTile(.reservation)
                                menuTile(.stock); menuTile(.inprogress); menuTile(.complete)
                            }
                            .padding(.bottom, 10)
                        } else {
                            VStack(spacing: verticalSpacing) {
                                if showMenu {
                                    HStack(spacing: horizontalSpacing) {
                                        menuTile(.add); menuTile(.wish); menuTile(.reservation)
                                    }
                                }
                                Color.clear.frame(height: orbSizeHome)
                                if showMenu {
                                    HStack(spacing: horizontalSpacing) {
                                        menuTile(.stock); menuTile(.inprogress); menuTile(.complete)
                                    }
                                }
                            }
                            .padding(.bottom, menuBottomOffsetPortrait)
                        }
                    }
                    .ignoresSafeArea(.container, edges: .bottom)
                    .allowsHitTesting(!showAddFlow && editingKit == nil)
                    .opacity(phase == .home ? 1 : 0)
                    .zIndex(10)

                    BlueOrbView(isAnimating: phase != .home, size: orbSizeHome)
                        .scaleEffect(lerp(from: launchScale, to: 1.0, t: progress))
                        // ✅ 修正: 確実に安全な位置へ配置する
                        .position(orbPosition(in: geo.size))
                        .allowsHitTesting(phase == .home && !showAddFlow && editingKit == nil)
                        .onTapGesture {
                            guard phase == .home else { return }
                            Haptics.tap()
                            if selected != nil { 
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = nil } 
                            } else {
                                // Clean state tap -> Add Flow
                                handleAddAction()
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.8) {
                            guard phase == .home else { return }
                            Haptics.longPress()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showCommanderMenu = true }
                        }
                        .zIndex(20)
                }
                .padding(.bottom, bottomSafeArea)
                
                // Layer 2: Commander Menu Overlay
                if showCommanderMenu {
                    CommanderMenuView(isPresented: $showCommanderMenu)
                        .zIndex(2000)
                        .transition(.opacity)
                }
            
                Color.clear
                    .fullScreenCover(isPresented: $showAddFlow, onDismiss: {
                        withAnimation { selected = nil }
                    }) {
                        AddRegistrationFlowOverlay(isPresented: $showAddFlow)
                    }

                
                if showPurchaseOverlay {
                    PurchaseOverlay(isPresented: $showPurchaseOverlay)
                        .zIndex(2000)
                        .transition(.opacity)
                }
                
                if editingKit != nil { KitDetailOverlay(kit: $editingKit).zIndex(1001) }
            }
            .task {
                guard !didStart else { return }
                didStart = true
                
                didStart = true
                

                
                phase = .launchHold; progress = 0; showMenu = false; selected = nil; bounceYOffset = 0
                try? await Task.sleep(nanoseconds: UInt64(launchHold * 1_000_000_000))
                phase = .moving
                withAnimation(.timingCurve(0.20, 0.95, 0.20, 1.0, duration: moveDuration)) { progress = 1 }
                try? await Task.sleep(nanoseconds: UInt64((moveDuration - landingHapticAdvance) * 1_000_000_000))
                Haptics.landingStrong()
                try? await Task.sleep(nanoseconds: UInt64(landingHapticAdvance * 1_000_000_000))
                await runLandingBounceWithHaptics()
                phase = .home
                withAnimation(.easeInOut(duration: menuFadeDuration)) { showMenu = true }
                // ジャイロ開始
                motionManager.startUpdates()
            }
        }
        .ignoresSafeArea(.keyboard)
    }
    

    

    
    private func calculateScale(proxy: GeometryProxy, in geo: GeometryProxy) -> CGFloat {
        let midX = proxy.frame(in: .global).midX
        let screenCenter = geo.size.width / 2
        let distance = abs(screenCenter - midX)
        let scale = 1.0 - (distance / (geo.size.width * 0.8))
        return max(0.85, scale)
    }
    
    @MainActor
    private func runLandingBounceWithHaptics() async {
        withAnimation(.easeOut(duration: bounceUp)) { bounceYOffset = -bounceHeight }
        try? await Task.sleep(nanoseconds: UInt64(bounceUp * 1_000_000_000))
        withAnimation(.interpolatingSpring(stiffness: 260, damping: 20)) { bounceYOffset = 0 }
        try? await Task.sleep(nanoseconds: UInt64(bounceDown * 1_000_000_000))
        Haptics.bounce()
        try? await Task.sleep(nanoseconds: UInt64(bounceGap * 1_000_000_000))
        withAnimation(.easeOut(duration: bounceUp)) { bounceYOffset = -(bounceHeight * 0.65) }
        try? await Task.sleep(nanoseconds: UInt64(bounceUp * 1_000_000_000))
        withAnimation(.interpolatingSpring(stiffness: 260, damping: 22)) { bounceYOffset = 0 }
        try? await Task.sleep(nanoseconds: UInt64(bounceDown * 1_000_000_000))
        Haptics.bounce()
    }

    private func menuTile(_ item: MenuItem) -> some View {
        IconTile.asset(name: item.assetName, size: iconSize, cornerRadius: iconCornerRadius, innerPadding: iconInnerPadding, isSelected: selected == item) {
            if item == .add {
                if isLimitReached {
                    Haptics.select()
                    withAnimation { showPurchaseOverlay = true }
                } else {
                    selected = .add; Haptics.tap(); showAddFlow = true
                }
                return
            }
            if selected != item { selected = item; Haptics.select() } else { Haptics.tap() }
        }
    }

    // ✅ 修正: 根本的解決
    private func orbPosition(in size: CGSize) -> CGPoint {
        // sizeはGeometryReaderのサイズ（実質Safe Area）
        let absoluteBottom = size.height
        
        if size.width > size.height {
            // Landscapeの場合
            // セーフエリア端(geo.width)から、さらに内側に100pt、下から60ptの「固定マージン」を確保
            // これで Dynamic Island やノッチがどこにあろうと確実に回避できる
            let x = size.width - 100
            let y = size.height - 60
            return CGPoint(x: x, y: y)
        } else {
            // Portraitの場合 (V24のロジックを維持)
            // menuBottomOffsetPortrait(-50) + iconSize(60) + spacing(12) + orbHalf(35) = -50+107 = 57
            // y = Height - 57 - 35 = Height - 92
            // 下部セーフエリア(34)を考慮しても、下から92pt浮いているので安全圏
            let endY = absoluteBottom - (menuBottomOffsetPortrait + iconSize + verticalSpacing + orbSizeHome / 2) - 35
            let x = size.width / 2
            let y = lerp(from: launchTopPadding + orbSizeLaunchVisual / 2, to: endY, t: progress)
            let strength = max(0, min(1, (progress - 0.92) / 0.08))
            let yBounced = y + bounceYOffset * strength
            return CGPoint(x: x, y: yBounced)
        }
    }
    
    private func lerp(from a: CGFloat, to b: CGFloat, t: CGFloat) -> CGFloat { a + (b - a) * t }
    
    private func handleAddAction() {
        if isLimitReached {
            Haptics.select()
            withAnimation { showPurchaseOverlay = true }
        } else {
            selected = .add; Haptics.tap(); showAddFlow = true
        }
    }
}



// MARK: - SubViews


struct KitCardView: View {
    let kit: Kit
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                let isComplete = (kit.statusValue == 4)
                let hasUserPhoto = (kit.completedImageURLString != nil && !kit.completedImageURLString!.isEmpty)
                let isUserChoice = (kit.displayModeValue == 1)
                
                let showPhoto = hasUserPhoto && (isComplete || isUserChoice)
                let urlStr = showPhoto ? kit.completedImageURLString : kit.imageURLString
                
                if let path = urlStr, !path.isEmpty {
                    if path.hasPrefix("asset://") {
                        let assetID = String(path.dropFirst(8))
                        PhAssetImage(localIdentifier: assetID).scaledToFill()
                    } else if let url = ImageLinker.resolve(urlString: path) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() } else { placeholder }
                        }
                    } else { placeholder }
                } else { placeholder }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            
            LinearGradient(
                colors: [.clear, .black.opacity(0.6), .black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)
            
            VStack(alignment: .leading, spacing: 4) {
                if !kit.series.isEmpty {
                    Text(kit.series)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(6)
                }
                Text(kit.title)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .shadow(color: .black, radius: 2, x: 0, y: 1)
                
                HStack(spacing: 4) {
                    Text(kit.maker)
                    if !kit.grade.isEmpty {
                        Text("・")
                        Text(kit.grade)
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if kit.statusValue == 4 && (kit.completedImageURLString != nil && !kit.completedImageURLString!.isEmpty) {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.0))
                            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                            .padding(12)
                    }
                    Spacer()
                }
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            Image(systemName: "cube.box")
                .font(.system(size: 50))
                .foregroundStyle(.secondary.opacity(0.3))
        }
    }
    
    private func loadLocalImage(named name: String) -> UIImage? {
        return ImageLinker.loadLocalImage(named: name)
    }
}

struct IconTile: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var themeManager = ThemeManager.shared
    private let techBlue = Color(red: 0.0, green: 0.65, blue: 0.90)
    
    let image: Image; let size: CGFloat; let cornerRadius: CGFloat; let innerPadding: CGFloat; let isSelected: Bool; let onTap: () -> Void
    static func asset(name: String, size: CGFloat, cornerRadius: CGFloat, innerPadding: CGFloat, isSelected: Bool, onTap: @escaping () -> Void) -> IconTile {
        IconTile(image: Image(name), size: size, cornerRadius: cornerRadius, innerPadding: innerPadding, isSelected: isSelected, onTap: onTap)
    }
    var body: some View {
        Button(action: onTap) {
            image
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .padding(innerPadding)
                .frame(width: size, height: size)
                .foregroundStyle(isSelected ? themeManager.currentTheme.mainColor : techBlue)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(themeManager.currentTheme.mainColor.opacity(isSelected ? 0.8 : 0.0), lineWidth: isSelected ? 2 : 0)
                )
                .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }
}

enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light); private static let medium = UIImpactFeedbackGenerator(style: .medium); private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    static func tap() { light.prepare(); light.impactOccurred() }
    static func select() { medium.prepare(); medium.impactOccurred() }
    static func longPress() { rigid.prepare(); rigid.impactOccurred() }
    static func landingStrong() { let heavy = UIImpactFeedbackGenerator(style: .heavy); heavy.prepare(); heavy.impactOccurred(intensity: 1.0) }
    static func bounce() { light.prepare(); light.impactOccurred(intensity: 0.55) }
}
