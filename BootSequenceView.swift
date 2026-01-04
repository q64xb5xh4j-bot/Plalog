// BootSequenceView.swift V7
// 1. バージョン管理ルールに基づき更新 (V6 -> V7)
// 2. 修正点: コンパイルエラー(AnyTransition.rotation)の修正
//    - transition修飾子から存在しない .rotation を削除
//    - 出現アニメーションを .scale(拡大) + .opacity(フェード) に一本化
//    - オーブの常時回転は内部の .rotationEffect で担保されているため演出上の劣化なし
// 3. 全文差し替えルール適用

import SwiftUI
import UIKit

struct BootSequenceView: View {
    var onComplete: () -> Void
    
    // テーママネージャーの参照
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // MARK: - State
    @State private var consoleLines: [ConsoleLine] = []
    @State private var progress: CGFloat = 0.0
    @State private var isAccessGranted: Bool = false
    @State private var opacity: Double = 1.0
    
    // 演出用ステート
    @State private var showScanner: Bool = false
    @State private var scannerRotation: Double = 0
    @State private var particleGathering: Double = 0
    @State private var flashScreen: Bool = false
    @State private var scanText: String = ""
    
    // OS起動オーブ用ステート
    @State private var showOrbWindow: Bool = false
    @State private var textVisible: Bool = false
    @State private var orbResonance: Double = 0.0 // オーブの共鳴発光用
    
    private let bootLogs = [
        "INITIALIZING CORE SYSTEMS...", "CHECKING MEMORY INTEGRITY...",
        "LOADING KIT DATABASE...", "CONNECTING TO ARCHIVE...",
        "CALIBRATING SENSORS...", "OPTIMIZING NEURAL LINK...",
        "ESTABLISHING SECURE CONNECTION...", "SYNCING COLLECTION DATA..."
    ]
    
    // バックロニム定義
    private let acronyms: [(letter: String, word: String)] = [
        ("P", "ERSONAL"),
        ("L", "OGISTICS"),
        ("A", "RCHIVE"),
        ("L", "IBRARY"),
        ("O", "PERATION"),
        ("G", "RID")
    ]
    
    struct ConsoleLine: Identifiable {
        let id = UUID()
        let text: String
    }

    var body: some View {
        ZStack {
            // 背景: 漆黒
            Color.black.ignoresSafeArea()
            
            // 完了時のフラッシュエフェクト
            themeManager.currentTheme.mainColor
                .ignoresSafeArea()
                .opacity(flashScreen ? 0.8 : 0.0)
                .animation(.easeOut(duration: 0.5), value: flashScreen)
            
            VStack {
                Spacer()
                
                // メイン演出エリア
                ZStack {
                    // 1. スキャナー (オーブが出るまで表示)
                    if showScanner && !showOrbWindow {
                        scannerView
                            .transition(.opacity)
                    }
                    
                    // 2. テーマカラー連動 発光オーブ
                    if showOrbWindow {
                        orbWindowView
                            // ✅ 修正: エラー原因の .rotation を削除し、拡大+フェードインのみに修正
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 0.1).combined(with: .opacity),
                                    removal: .opacity
                                )
                            )
                    }
                }
                .frame(height: 380) // オーブのサイズに合わせて調整
                
                // スキャン状態テキスト
                if showScanner && !showOrbWindow && !isAccessGranted {
                    Text(scanText)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                        .tracking(2)
                        .shadow(color: themeManager.currentTheme.mainColor.opacity(0.8), radius: 5)
                        .padding(.top, 20)
                        .transition(.opacity)
                }
                
                Spacer()
                
                // ログとプログレス
                if !isAccessGranted && !showScanner && !showOrbWindow {
                    logAndProgressView
                }
                
                // ACCESS GRANTED 表示
                if isAccessGranted {
                    Text("SYSTEM ONLINE")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .tracking(4)
                        .padding(.top, 20)
                        .shadow(color: themeManager.currentTheme.mainColor, radius: 15)
                        .transition(.opacity)
                        .padding(.bottom, 50)
                }
            }
        }
        .opacity(opacity)
        .onAppear {
            startBootSequence()
        }
    }
    
    // MARK: - Subviews
    
    // スキャナービュー (変更なし)
    private var scannerView: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(colors: [themeManager.currentTheme.mainColor.opacity(0), themeManager.currentTheme.mainColor, .white], center: .center),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 150, height: 150)
                .rotationEffect(.degrees(scannerRotation))
                .shadow(color: themeManager.currentTheme.mainColor, radius: 10)
            
            Circle()
                .trim(from: 0, to: 0.5)
                .stroke(
                    AngularGradient(colors: [themeManager.currentTheme.mainColor.opacity(0), themeManager.currentTheme.mainColor.opacity(0.5), .white], center: .center),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 110, height: 110)
                .rotationEffect(.degrees(-scannerRotation * 1.5))

            ForEach(0..<8) { i in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .offset(x: 100)
                    .rotationEffect(.degrees(Double(i) * 45))
                    .scaleEffect(1.0 - particleGathering)
                    .opacity(1.0 - particleGathering)
            }
            .rotationEffect(.degrees(scannerRotation * 0.5))
        }
    }
    
    // テーマカラー反映版 発光オーブウィンドウ
    private var orbWindowView: some View {
        ZStack {
            // 1. オーブの本体（球体背景）
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            themeManager.currentTheme.mainColor.opacity(0.3 + orbResonance * 0.2), // 中心: 明るい
                            themeManager.currentTheme.mainColor.opacity(0.1), // 中間
                            Color.black.opacity(0.8) // 外縁: 暗い
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 180
                    )
                )
                // 外側の発光リング
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [themeManager.currentTheme.mainColor.opacity(0.8), themeManager.currentTheme.mainColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .rotationEffect(.degrees(scannerRotation * 0.2)) // ゆっくり回転
                )
                // 全体の強い発光（ブルーム効果）
                .shadow(color: themeManager.currentTheme.mainColor.opacity(0.5 + orbResonance * 0.3), radius: 30)
                .frame(width: 360, height: 360)
            
            // 2. 内部の透かしロゴ (奥行き表現)
            Image(systemName: "cube")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .foregroundStyle(themeManager.currentTheme.mainColor)
                .opacity(0.1)
                .rotation3DEffect(.degrees(20), axis: (x: 1, y: 1, z: 0))
            
            // 3. メインのアクロニム表示エリア (中央揃え)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(acronyms.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 0) {
                        // 頭文字 (テーマカラーで強く発光)
                        Text(item.letter)
                            .font(.system(size: 40, weight: .heavy, design: .serif))
                            .foregroundStyle(themeManager.currentTheme.mainColor)
                            .shadow(color: themeManager.currentTheme.mainColor.opacity(0.8), radius: 10)
                            .frame(width: 45, alignment: .center)
                        
                        // 残りの文字 (白でクッキリ)
                        Text(item.word)
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.3), radius: 2)
                    }
                    // アニメーション
                    .opacity(textVisible ? 1.0 : 0.0)
                    .scaleEffect(textVisible ? 1.0 : 0.8) // 出現時に少し拡大
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.6)
                        .delay(Double(index) * 0.08),
                        value: textVisible
                    )
                }
            }
        }
    }
    
    private var logAndProgressView: some View {
        VStack {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(consoleLines) { line in
                    Text(line.text)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(themeManager.currentTheme.mainColor.opacity(0.8))
                        .shadow(color: themeManager.currentTheme.mainColor.opacity(0.3), radius: 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)
            .frame(height: 150)
            
            Spacer().frame(height: 30)
            
            VStack(spacing: 8) {
                HStack {
                    Text("LOADING SYSTEM...")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.gray)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.gray.opacity(0.2))
                        Rectangle()
                            .fill(LinearGradient(colors: [themeManager.currentTheme.mainColor, .white], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * progress)
                            .shadow(color: themeManager.currentTheme.mainColor.opacity(0.6), radius: 5)
                    }
                }
                .frame(height: 4).cornerRadius(2)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - Boot Logic
    private func startBootSequence() {
        Task {
            // 1. ログ出力
            let logsToShow = bootLogs.shuffled().prefix(4)
            for (index, log) in logsToShow.enumerated() {
                try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 0.05...0.1) * 1_000_000_000))
                await MainActor.run {
                    addLog(log); Haptics.tick()
                    progress = min(progress + 0.15, 0.6)
                }
            }
            
            // 2. 認証フェーズ
            try? await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))
            await MainActor.run {
                addLog("INITIATING NEURAL LINK...")
                withAnimation(.easeInOut(duration: 0.5)) { showScanner = true }
                scanText = "SYNCING BIOMETRIC DATA..."
                
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    scannerRotation = 360
                }
                withAnimation(.easeIn(duration: 1.5)) {
                    particleGathering = 1.0
                }
            }
            
            // 3. オーブ展開
            try? await Task.sleep(nanoseconds: UInt64(1.6 * 1_000_000_000))
            await MainActor.run {
                Haptics.heavy()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showOrbWindow = true
                }
            }
            
            // 4. 文字表示と共鳴エフェクト
            try? await Task.sleep(nanoseconds: UInt64(0.3 * 1_000_000_000))
            await MainActor.run {
                textVisible = true
                scanText = ""
            }
            
            for _ in 0..<6 {
                // 文字が出るたびにオーブを共鳴発光させる
                await MainActor.run { withAnimation(.easeOut(duration: 0.1)) { orbResonance = 1.0 } }
                Haptics.tick()
                try? await Task.sleep(nanoseconds: UInt64(0.08 * 1_000_000_000))
                await MainActor.run { withAnimation(.easeIn(duration: 0.1)) { orbResonance = 0.0 } }
            }
            
            // 5. 完了フラッシュ
            try? await Task.sleep(nanoseconds: UInt64(1.2 * 1_000_000_000))
            await MainActor.run {
                flashScreen = true
                Haptics.success()
                
                withAnimation(.spring()) {
                    isAccessGranted = true
                    progress = 1.0
                    showOrbWindow = false
                }
            }
            
            // 6. 遷移
            try? await Task.sleep(nanoseconds: UInt64(0.8 * 1_000_000_000))
            await MainActor.run { onComplete() }
        }
    }
    
    private func addLog(_ text: String) {
        consoleLines.append(ConsoleLine(text: "> " + text))
        if consoleLines.count > 6 { consoleLines.removeFirst() }
    }
    
    // MARK: - Haptics Helper
    private enum Haptics {
        static func tick() { let g = UIImpactFeedbackGenerator(style: .light); g.prepare(); g.impactOccurred(intensity: 0.6) }
        static func heavy() { let g = UIImpactFeedbackGenerator(style: .heavy); g.prepare(); g.impactOccurred(intensity: 1.0) }
        static func success() { let g = UINotificationFeedbackGenerator(); g.prepare(); g.notificationOccurred(.success) }
    }
}
