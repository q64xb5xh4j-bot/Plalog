// BarcodeScannerView.swift V3
// 1. バージョン管理ルールに基づき更新 (V2 -> V3)
// 2. 修正点: 画面回転(Landscape/Portrait)への対応
//    - iPad等で横持ちした際にカメラ映像が90度回転してしまう問題を修正
//    - viewDidLayoutSubviews()でプレビューレイヤーのOrientationを動的に更新
//    - Vision(OCR)のリクエストOrientationもデバイスの向きに合わせて調整
// 3. 全文差し替えルール適用

import SwiftUI
import AVFoundation
import Vision

// MARK: - Barcode Scanner View (Hybrid)
// カメラを使用してJANコード(EAN-13)とVisionによる文字認識を並行して行う

struct BarcodeScannerView: UIViewControllerRepresentable {
    // スキャン成功時に呼ばれるクロージャ
    var onFound: (String) -> Void
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onFound = onFound
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

// MARK: - Scanner Logic (Hybrid: Metadata + Vision)
class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var onFound: ((String) -> Void)?
    
    // Vision: OCR Request
    private var textRecognitionRequest: VNRecognizeTextRequest?
    private var lastOCRTime: Date = Date()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupVision()
    }
    
    // ✅ 画面回転時にレイアウトとオリエンテーションを更新
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
        updatePreviewLayerOrientation()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .hd1280x720
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if (session.canAddInput(videoInput)) {
            session.addInput(videoInput)
        } else {
            return
        }
        
        // 1. Metadata Output (JAN Code)
        let metadataOutput = AVCaptureMetadataOutput()
        if (session.canAddOutput(metadataOutput)) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean13]
        }
        
        // 2. Video Data Output (Vision OCR)
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        let videoQueue = DispatchQueue(label: "com.pralog.ocrQueue")
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        if (session.canAddOutput(videoOutput)) {
            session.addOutput(videoOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer!)
        
        captureSession = session
    }
    
    // ✅ プレビューレイヤーの向きをデバイスの向きに合わせる
    private func updatePreviewLayerOrientation() {
        guard let connection = previewLayer?.connection, connection.isVideoOrientationSupported else { return }
        
        let currentOrientation = UIDevice.current.orientation
        
        switch currentOrientation {
        case .portrait:
            connection.videoOrientation = .portrait
        case .landscapeRight:
            connection.videoOrientation = .landscapeLeft // カメラセンサーの関係で逆になる場合が多い
        case .landscapeLeft:
            connection.videoOrientation = .landscapeRight
        case .portraitUpsideDown:
            connection.videoOrientation = .portraitUpsideDown
        default:
            // FlatやFaceUpなどの場合は現在の設定を維持するか、UIの向きから判定する
            if let windowScene = view.window?.windowScene {
                switch windowScene.interfaceOrientation {
                case .portrait: connection.videoOrientation = .portrait
                case .landscapeRight: connection.videoOrientation = .landscapeRight
                case .landscapeLeft: connection.videoOrientation = .landscapeLeft
                case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
                default: break
                }
            }
        }
    }
    
    private func setupVision() {
        textRecognitionRequest = VNRecognizeTextRequest { [weak self] (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            self?.processOCRResults(observations)
        }
        textRecognitionRequest?.recognitionLevel = .accurate
        textRecognitionRequest?.usesLanguageCorrection = true
    }
    
    private func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let session = self?.captureSession, !session.isRunning {
                session.startRunning()
            }
        }
    }
    
    private func stopSession() {
        if let session = captureSession, session.isRunning {
            session.stopRunning()
        }
    }
    
    // MARK: - Barcode Delegate
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            stopSession()
            onFound?(stringValue)
        }
    }
    
    // MARK: - Video Data Delegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        if now.timeIntervalSince(lastOCRTime) < 0.5 { return }
        lastOCRTime = now
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let request = textRecognitionRequest else { return }
        
        // ✅ デバイスの向きに合わせてOCRの読み取り方向を指定
        // 注意: CGImagePropertyOrientation は AVCaptureVideoOrientation とは定義が異なる
        let orientation = currentOCROrientation()
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("OCR Error: \(error)")
        }
    }
    
    // ✅ OCR用の向き判定ロジック
    private func currentOCROrientation() -> CGImagePropertyOrientation {
        let deviceOrientation = UIDevice.current.orientation
        
        switch deviceOrientation {
        case .portrait: return .right
        case .landscapeRight: return .up
        case .landscapeLeft: return .down
        case .portraitUpsideDown: return .left
        default: return .right // デフォルト（縦持ち想定）
        }
    }
    
    private func processOCRResults(_ observations: [VNRecognizedTextObservation]) {
        let recognizedStrings = observations.compactMap { $0.topCandidates(1).first?.string }
        
        if !recognizedStrings.isEmpty {
            let keywords = ["HG", "MG", "RG", "PG", "EG", "1/144", "1/100", "GUNDAM", "Ver.Ka"]
            for str in recognizedStrings {
                for key in keywords {
                    if str.localizedCaseInsensitiveContains(key) {
                        print("👁️ Vision Detected: \(str)")
                    }
                }
            }
        }
    }
}
