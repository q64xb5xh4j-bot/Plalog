
import SwiftUI
import VisionKit
import Vision


import SwiftUI
import VisionKit
import Vision

// Reverted to simple scanner as per user request (Editor is for Box Art only)
struct OCRCameraView: UIViewControllerRepresentable {
    var onCompletion: (UIImage?, String, String?) -> Void // Image, Title, Maker
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        context.coordinator.scanner = scanner
        
        // No custom overlay needed for "Just Text" mode if tapping is the primary interaction?
        // User said: "ocrは撮影しなくていいんだよ テキストだけ読み取ってくれたらね"
        // But previously we had a capture button?
        // Let's keep the Capture Button but maybe it just grabs text?
        // Actually, previous implementation (V89/V90) had a button overlay.
        // Let's keep it for manual "Capture what's seen" if tap fails, or remove if user insists on "Text Only".
        // Safe bet: Keep button, but it behaves same as tap (Text extraction).
        
        let overlay = makeOverlay(context: context)
        scanner.view.addSubview(overlay)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlay.bottomAnchor.constraint(equalTo: scanner.view.bottomAnchor, constant: -100),
            overlay.centerXAnchor.constraint(equalTo: scanner.view.centerXAnchor),
            overlay.leadingAnchor.constraint(greaterThanOrEqualTo: scanner.view.leadingAnchor, constant: 20),
            overlay.trailingAnchor.constraint(lessThanOrEqualTo: scanner.view.trailingAnchor, constant: -20)
        ])
        
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    private func makeOverlay(context: Context) -> UIView {
        let label = UILabel()
        label.text = "選択したいテキストをタッチしてください"
        label.textColor = .white.withAlphaComponent(0.9)
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.8
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowRadius = 4
        return label
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: OCRCameraView
        weak var scanner: DataScannerViewController?
        
        init(parent: OCRCameraView) {
            self.parent = parent
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            processItem(item)
        }
        
        private func processItem(_ item: RecognizedItem) {
            switch item {
            case .text(let text):
                let generator = UIImpactFeedbackGenerator(style: .medium); generator.impactOccurred()
                
                // User requested NO SHUTTER SOUND.
                // capturePhoto() triggers sound.
                // We will rely solely on the tapped text.
                // Image and full-frame heuristics are disabled to ensure silence.
                
                parent.onCompletion(nil, text.transcript, nil) // Image nil, Title, Maker nil
                parent.dismiss()

            default: break
            }
        }
        

    }
}


// Shared OCR Logic
struct OCRLogic {
    static func heuristicExtraction(from image: UIImage) -> (String, String?) {
        guard let cgImage = image.cgImage else { return ("", nil) }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ja-JP", "en-US"]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        
        guard let observations = request.results else { return ("", nil) }
        
        let texts = observations.compactMap { $0.topCandidates(1).first?.string }
            .filter { $0.count > 1 }
        
        let makers = ["BANDAI", "KOTOBUKIYA", "TAMIYA", "AOSHIMA", "HASEGAWA", "WAVE", "FUJIMI", "MODEROID", "GOOD SMILE"]
        var detectedMaker: String? = nil
        
        for t in texts {
            let upper = t.uppercased()
            for m in makers {
                if upper.contains(m) {
                    detectedMaker = m
                    break
                }
            }
            if detectedMaker != nil { break }
        }
        
        let noise = ["SCALE", "SPIRITS", "JAPAN", "MADE IN", "対象年齢", "WARNING", "BAN", "DAI"]
        var potentialTitle = ""
        for t in texts {
            if noise.contains(where: { t.uppercased().contains($0) }) { continue }
            if let m = detectedMaker, t.uppercased().contains(m) { continue }
            if t.count > 3 {
                potentialTitle = t
                break
            }
        }
        
        return (potentialTitle, detectedMaker)
    }
}
