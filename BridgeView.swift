import SwiftUI
import SwiftData

struct BridgeView: View {
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            BridgeContent(showBackButton: true, onDismiss: { isPresented = false })
        }
    }
}
