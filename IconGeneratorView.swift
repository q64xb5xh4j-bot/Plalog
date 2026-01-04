// IconGeneratorView.swift
// コマンダー用アイコン生成ビュー
// Xcodeのプレビューで確認し、スクリーンショットを撮ってアイコンとして使用するためのビューです。

import SwiftUI

struct IconGeneratorView: View {
    var body: some View {
        ZStack {
            // 1. 背景: 漆黒
            Color(red: 5/255, green: 10/255, blue: 20/255)
            
            // 2. サイバーグリッド
            CyberGrid()
                .opacity(0.3)
            
            // 3. アークリアクター風オーブ
            ZStack {
                // 外側のグロー（多重円）
                ForEach(0..<5) { i in
                    Circle()
                        .stroke(Color.cyan.opacity(0.1 + Double(i) * 0.05), lineWidth: 2)
                        .frame(width: 800 + CGFloat(i * 10), height: 800 + CGFloat(i * 10))
                }
                
                // メインリング
                Circle()
                    .stroke(
                        LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 20
                    )
                    .frame(width: 760, height: 760)
                    .shadow(color: .cyan.opacity(0.8), radius: 20)
                
                // 3点マーカー
                ForEach(0..<3) { i in
                    Rectangle()
                        .fill(Color.cyan)
                        .frame(width: 20, height: 60)
                        .offset(y: -400)
                        .rotationEffect(.degrees(Double(i) * 120))
                }
            }
            
            // 4. ロゴシンボル "P"
            CommanderPSymbol()
                .fill(
                    LinearGradient(colors: [.cyan, .white], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 400, height: 500)
                .shadow(color: .cyan, radius: 15)
                .offset(x: 20) // 微調整
            
        }
        .frame(width: 1024, height: 1024) // AppStoreアイコンサイズ
        .ignoresSafeArea()
    }
}

// グリッド描画
struct CyberGrid: View {
    var body: some View {
        Path { path in
            let step: CGFloat = 80
            for x in stride(from: 0, to: 1024, by: step) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: 1024))
            }
            for y in stride(from: 0, to: 1024, by: step) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: 1024, y: y))
            }
        }
        .stroke(Color.cyan, lineWidth: 1)
    }
}

// Pマーク描画
struct CommanderPSymbol: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = rect.width
        let h = rect.height
        let thickness: CGFloat = w * 0.35
        
        // 縦棒
        path.addRect(CGRect(x: 0, y: 0, width: thickness, height: h))
        
        // ループ部分（上）
        path.addRect(CGRect(x: 0, y: 0, width: w, height: thickness))
        // ループ部分（右）
        path.addRect(CGRect(x: w - thickness, y: 0, width: thickness, height: h * 0.6))
        // ループ部分（中）
        path.addRect(CGRect(x: 0, y: h * 0.6 - thickness, width: w, height: thickness))
        
        return path
    }
}

#Preview {
    IconGeneratorView()
        .previewLayout(.fixed(width: 1024, height: 1024))
}
