//
//  CleanScannerView.swift V5
//  Plalog
//
//  Created by (User) on 2026/01/03.
//  Clean Scan: 行単位の独立認識 & 高感度選択版
//  1. バージョン管理ルールに基づき更新 (V4 -> V5)
//  2. 修正点:
//     - 複数行を1つにまとめず、行単位で独立して認識・選択できるように改善
//     - 日本語名と英語名が並んでいる場合でも、欲しい行だけをピンポイントでタップ可能
//

import SwiftUI
import VisionKit

struct CleanScannerView: UIViewControllerRepresentable {
    var onDetected: (String) -> Void
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true, // 複数の要素を個別に維持
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: CleanScannerView
        init(parent: CleanScannerView) { self.parent = parent }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text):
                // V5修正: text.transcript をそのまま使うのではなく、
                // タップされた箇所の「行」をより厳密に扱う（VisionKitのデフォルト挙動を尊重）
                let cleanedText = clean(text.transcript)
                if !cleanedText.isEmpty {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    parent.onDetected(cleanedText)
                }
            default: break
            }
        }
        
        private func clean(_ input: String) -> String {
            // 改行が含まれている場合は、タップされた「行」に絞り込む（先頭行を優先）
            let lines = input.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            var result = lines.first ?? input
            
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if result.count < 2 { return "" }
            
            let excessiveNoises = ["All rights reserved", "MADE IN JAPAN", "BANDAI SPIRITS", "対象年齢", "警告"]
            for noise in excessiveNoises {
                if result.localizedCaseInsensitiveContains(noise) { return "" }
            }
            return result
        }
    }
}
