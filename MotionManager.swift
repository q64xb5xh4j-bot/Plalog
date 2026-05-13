import SwiftUI
import CoreMotion
import Combine

// MARK: - Motion Manager
class MotionManager: ObservableObject {
    private let manager = CMMotionManager()
    @Published var pitch: Double = 0.0
    @Published var roll: Double = 0.0
    
    func startUpdates() {
        if manager.isDeviceMotionAvailable {
            manager.deviceMotionUpdateInterval = 1.0 / 60.0
            manager.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
                guard let data = data else { return }
                // 傾きデータを滑らかに反映
                withAnimation(.linear(duration: 0.1)) {
                    self?.roll = data.attitude.roll
                    self?.pitch = data.attitude.pitch
                }
            }
        }
    }
    
    func stopUpdates() {
        manager.stopDeviceMotionUpdates()
    }
}
