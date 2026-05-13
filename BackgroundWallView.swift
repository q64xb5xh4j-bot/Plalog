import SwiftUI
import SwiftData
import Photos

// MARK: - Background Wall View
struct BackgroundWallView: View {
    let kits: [Kit]
    
    var body: some View {
        GeometryReader { geo in
            // Grid settings
            let itemSize: CGFloat = 60
            let spacing: CGFloat = 25
            let totalItemWidth = itemSize + spacing
            let columns = max(1, Int(geo.size.width / totalItemWidth))
            
            ZStack {
                // Performance Optimization: Limit to top 80 items to prevent memory crash
                ForEach(Array(kits.prefix(80).enumerated()), id: \.element.id) { index, kit in
                    let col = index % columns
                    let row = index / columns
                    
                    let x = CGFloat(col) * totalItemWidth + (totalItemWidth / 2)
                    let y = CGFloat(row) * totalItemWidth + (totalItemWidth / 2) + 50
                    
                    wallItem(kit: kit)
                        .position(x: x, y: y)
                }
            }
            .rotation3DEffect(.degrees(10), axis: (x: 1, y: 0, z: 0), perspective: 0.3)
            .ignoresSafeArea()
            
            LinearGradient(colors: [Color(uiColor: .systemBackground).opacity(0.0), Color(uiColor: .systemBackground).opacity(0.6)], startPoint: .top, endPoint: .bottom).ignoresSafeArea().allowsHitTesting(false)
        }
    }
    
    private func wallItem(kit: Kit) -> some View {
        let isComplete = (kit.statusValue == 4)
        let hasUserPhoto = (kit.completedImageURLString != nil && !kit.completedImageURLString!.isEmpty)
        let isUserChoice = (kit.displayModeValue == 1)
        
        let showPhoto = hasUserPhoto && (isComplete || isUserChoice)
        let urlToLoad = showPhoto ? kit.completedImageURLString : kit.imageURLString
        
        return Group {
            if let urlStr = urlToLoad, !urlStr.isEmpty {
                if urlStr.hasPrefix("asset://") {
                    let assetID = String(urlStr.dropFirst(8))
                    PhAssetImage(localIdentifier: assetID).scaledToFill()
                } else if let url = ImageLinker.resolve(urlString: urlStr) {
                    AsyncImage(url: url) { phase in
                         if let image = phase.image { image.resizable().scaledToFill() }
                         else { Color.gray.opacity(0.3) }
                    }
                } else { Color.gray.opacity(0.1) }
            } else { Color.gray.opacity(0.1) }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(0.9)
        .grayscale(0.4)
    }
}
