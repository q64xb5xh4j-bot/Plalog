import SwiftUI
import Combine

struct LootReportView: View {
    let kits: [Kit]
    let title: String // "PROCUREMENT ORDER", "ACQUISITION LOG", etc.
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Fixed Render Size: 1080 x 1350 (4:5 Ratio)
    var body: some View {
        ZStack {
            // 1. Background (Dark Sci-fi Paper)
            Color.black
            
            // Grid Pattern
            GeometryReader { geo in
                Path { path in
                    let step: CGFloat = 40
                    for x in stride(from: 0, to: geo.size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    for y in stride(from: 0, to: geo.size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
            }
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(themeManager.currentTheme.mainColor)
                        Text("PRALOG LOGISTICS")
                            .font(.system(size: 24, weight: .heavy, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(Date(), format: .dateTime.year().month().day())
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(.gray)
                    }
                    .padding(.bottom, 10)
                    
                    Rectangle().frame(height: 4).foregroundStyle(themeManager.currentTheme.mainColor)
                    
                    HStack {
                        Text(title)
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("Count: \(kits.count)")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(themeManager.currentTheme.mainColor)
                    }
                }
                .padding(40)
                
                // List
                VStack(spacing: 2) {
                    // Table Header
                    HStack {
                        Text("ITEM").font(.system(size: 14, weight: .bold)).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading)
                        Text("MAKER").font(.system(size: 14, weight: .bold)).foregroundStyle(.gray).frame(width: 200, alignment: .leading)
                        Text("GRADE").font(.system(size: 14, weight: .bold)).foregroundStyle(.gray).frame(width: 150, alignment: .trailing)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 10)
                    
                    // Items (Max 15 items to fit?) - We might need to slice or handle overflow, but for now simple list
                    ForEach(kits.prefix(12)) { kit in
                        HStack(alignment: .top) {
                            Text(kit.title)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text(kit.maker)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.gray)
                                .frame(width: 200, alignment: .leading)
                                .lineLimit(1)
                            
                            Text(kit.grade)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(themeManager.currentTheme.mainColor)
                                .frame(width: 150, alignment: .trailing)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 40)
                        .background(Color.white.opacity(0.05))
                    }
                    
                    if kits.count > 12 {
                        HStack {
                            Spacer()
                            Text("+ \(kits.count - 12) more items...")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(.gray)
                                .padding(20)
                        }
                    }
                    
                    Spacer()
                }
                
                // Footer
                VStack {
                    Divider().overlay(.white.opacity(0.2))
                    HStack {
                        Text("AUTHORIZED BY PILOT")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Spacer()
                        Text("GENERATED VIA PRALOG")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    .padding(40)
                    
                    // Barcode Decal
                    Rectangle()
                        .fill(Color.white)
                        .frame(height: 20)
                        .mask(
                            HStack(spacing: 2) {
                                ForEach(0..<60) { _ in
                                    Rectangle().frame(width: CGFloat.random(in: 1...4))
                                }
                            }
                        )
                        .padding(.bottom, 40)
                        .opacity(0.5)
                }
            }
        }
        .frame(width: 1080, height: 1350)
        .background(Color.black)
    }
}
