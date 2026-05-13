import SwiftUI
import MultipeerConnectivity
import SwiftData
import AudioToolbox
import UIKit // Needed for UINotificationFeedbackGenerator

struct P2PSyncView: View {
    @Binding var isPresented: Bool
    @StateObject private var p2pManager = P2PManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @Environment(\.modelContext) private var modelContext
    @Query private var allKits: [Kit]
    
    // Helper for Sound
    private func playSuccessSound() {
        AudioServicesPlaySystemSound(1001) 
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 24))
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                    Text("DIRECT SYNC")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    if !p2pManager.isSyncing {
                        Button {
                            p2pManager.stop()
                            withAnimation { isPresented = false }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.gray)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                
                // Status Area
                VStack(spacing: 16) {
                    ZStack {
                        // Base Circle
                        Circle()
                            .stroke(themeManager.currentTheme.mainColor.opacity(0.3), lineWidth: 2)
                            .frame(width: 120, height: 120)
                        
                        if p2pManager.isCompleted {
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 140, height: 140)
                                .transition(.scale)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 80, weight: .bold))
                                .foregroundStyle(Color.green)
                                .shadow(radius: 10)
                                .transition(.scale.combined(with: .opacity))
                        } else if p2pManager.isSyncing {
                            // Pulsing Ring
                            Circle()
                                .stroke(themeManager.currentTheme.mainColor, lineWidth: 4)
                                .frame(width: 120, height: 120)
                                .scaleEffect(1.1)
                                .opacity(0.5)
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: p2pManager.isSyncing)
                            
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                                .rotationEffect(.degrees(360))
                                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: p2pManager.isSyncing)
                        } else {
                            // Scanning Ring
                            if p2pManager.isScanning && p2pManager.connectedPeers.isEmpty {
                                Circle()
                                    .trim(from: 0, to: 0.7)
                                    .stroke(themeManager.currentTheme.mainColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .frame(width: 120, height: 120)
                                    .rotationEffect(Angle(degrees: p2pManager.isScanning ? 360 : 0))
                                    .animation(Animation.linear(duration: 2).repeatForever(autoreverses: false), value: p2pManager.isScanning)
                            }
                            
                            Image(systemName: "iphone.gen3")
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                        }
                    }
                    
                    if p2pManager.isCompleted {
                        Text("同期完了！")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                            .shadow(radius: 5)
                            .padding(.top, 10)
                    } else {
                        Text(p2pManager.statusMessage)
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical, 40)
                                
                // Device List (Keep existing code...)
                VStack(alignment: .leading) {
                    Text("NEARBY DEVICES")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView {
                        VStack(spacing: 10) {
                            if p2pManager.availablePeers.isEmpty {
                                Text("探しています...")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                    .padding()
                            } else {
                                ForEach(p2pManager.availablePeers, id: \.self) { peer in
                                    HStack {
                                        Image(systemName: "ipad.and.iphone")
                                            .foregroundStyle(themeManager.currentTheme.mainColor)
                                        Text(peer.displayName)
                                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white)
                                        Spacer()
                                        
                                        if p2pManager.connectedPeers.contains(peer) {
                                            Text("CONNECTED")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .padding(6)
                                                .background(Color.green.opacity(0.2))
                                                .foregroundStyle(.green)
                                                .cornerRadius(4)
                                        } else {
                                            Button("接続") {
                                                LocalHaptics.select()
                                                p2pManager.invite(peer: peer)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(themeManager.currentTheme.mainColor)
                                        }
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Sync Action
                if !p2pManager.connectedPeers.isEmpty && !p2pManager.isSyncing && !p2pManager.isCompleted {
                    Button(action: {
                        LocalHaptics.select()
                        p2pManager.isSyncing = true
                        p2pManager.statusMessage = "データを準備中..."
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            Task {
                                if let data = await DataTransferManager.shared.prepareSyncData(kits: allKits, type: .initial) {
                                    p2pManager.send(data: data)
                                } else {
                                    p2pManager.statusMessage = "データ生成エラー"
                                    p2pManager.isSyncing = false
                                }
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("START SYNC")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.currentTheme.mainColor)
                        .cornerRadius(12)
                    }
                    .padding()
                } else if p2pManager.isCompleted {
                    Button(action: {
                        withAnimation {
                            p2pManager.isCompleted = false
                            p2pManager.statusMessage = "準備完了"
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("完了 (閉じる)")
                        }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                            .shadow(color: .green.opacity(0.5), radius: 10)
                    }
                    .padding()
                } else {
                    Spacer().frame(height: 60) // Placeholder
                }
                
                Spacer()
            }
        }
        .onAppear {

            p2pManager.onDataReceived = { data in
                Task {
                    let (message, envelope) = await DataTransferManager.shared.mergeSyncData(jsonData: data, modelContext: modelContext)
                    
                    // 画像リクエスト処理 (送信側)
                    if let env = envelope, env.type == .requestImages, let requests = env.imageRequests {
                        p2pManager.statusMessage = "画像を転送中: 0/\(requests.count)枚"
                        
                        // Strict Serial Sending to prevent MCSession overload
                        // 一気に送ると接続が切れるため、1つ完了してから次を送る
                        DispatchQueue.global(qos: .userInitiated).async {
                            let total = requests.count
                            var successCount = 0
                            var failCount = 0
                            
                            for (index, filename) in requests.enumerated() {
                                let semaphore = DispatchSemaphore(value: 0)
                                DispatchQueue.main.async {
                                    p2pManager.statusMessage = "画像を転送中: \(index + 1)/\(total)枚\n(\(filename))"
                                }
                                
                                p2pManager.sendResource(filename: filename) { error in
                                    if let e = error {
                                        print("Send Error [\(filename)]: \(e)")
                                        failCount += 1
                                    } else {
                                        successCount += 1
                                    }
                                    semaphore.signal()
                                }
                                
                                semaphore.wait() // Wait for completion
                                
                                // 少し休憩 (安定性重視)
                                Thread.sleep(forTimeInterval: 0.2)
                            }
                            
                            DispatchQueue.main.async {
                                p2pManager.statusMessage = "転送完了\n成功: \(successCount), 失敗: \(failCount)"
                                p2pManager.isSyncing = false
                                p2pManager.isCompleted = true
                                playSuccessSound()
                            }
                        }
                        return
                    }
                    
                    p2pManager.statusMessage = message
                    
                    // 画像不足チェック & リクエスト (受信側)
                    var hasPendingRequests = false
                    if envelope != nil {
                         let missing = DataTransferManager.shared.checkMissingImages(modelContext: modelContext)
                         if !missing.isEmpty {
                             hasPendingRequests = true
                             // Task内なのでDispatchQueue.main.asyncAfterは不要かもだが、タイミング調整のため維持
                             try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                             p2pManager.statusMessage = "画像リクエスト送信中: \(missing.count)枚"
                             if let reqData = DataTransferManager.shared.prepareImageRequest(filenames: missing) {
                                 p2pManager.send(data: reqData)
                             }
                         }
                    }
                    
                    // 双方向同期: 返信処理
                    if let env = envelope, env.type == .initial {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 sec
                        p2pManager.statusMessage = "データを返信中..."
                        if let replyData = await DataTransferManager.shared.prepareSyncData(kits: allKits, type: .response) {
                            p2pManager.send(data: replyData)
                        }
                        // 返信したらこの端末のタスクはひとまず完了だが、
                        // 相手からの画像リクエストが来る可能性があるので isCompletedにはしない
                    } else if !hasPendingRequests {
                        // 返信不要 かつ 画像リクエスト予定もなければ完了
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        p2pManager.isSyncing = false
                        p2pManager.isCompleted = true
                        playSuccessSound()
                    }
                }
            }
            p2pManager.start()
        }
        .onDisappear {
            p2pManager.stop()
        }
        .alert("接続リクエスト", isPresented: $p2pManager.isPresentingInvitation) {
            Button("拒否", role: .cancel) {
                p2pManager.rejectInvitation()
            }
            Button("接続") {
                p2pManager.acceptInvitation()
            }
        } message: {
            Text("\(p2pManager.requestingPeerName) からの接続を許可しますか？")
        }
    }
}
