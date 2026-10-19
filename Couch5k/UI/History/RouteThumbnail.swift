import SwiftUI

/// Tile-free sketch of a route for list rows: the path normalized into the frame.
struct RouteThumbnail: View {
    let route: [RoutePointValue]

    var body: some View {
        ZStack {
            Theme.surface
            if route.count > 1 {
                Canvas { ctx, size in
                    let lats = route.map(\.latitude), lons = route.map(\.longitude)
                    guard let minLat = lats.min(), let maxLat = lats.max(),
                          let minLon = lons.min(), let maxLon = lons.max() else { return }
                    // Scale longitude by cos(latitude) so the sketch keeps its real aspect ratio.
                    let cosLat = cos((minLat + maxLat) / 2 * .pi / 180)
                    let spanX = max((maxLon - minLon) * cosLat, 1e-6)
                    let spanY = max(maxLat - minLat, 1e-6)
                    let inset = 8.0
                    let scale = min((size.width - 2 * inset) / spanX, (size.height - 2 * inset) / spanY)
                    let drawW = spanX * scale, drawH = spanY * scale
                    let ox = (size.width - drawW) / 2, oy = (size.height - drawH) / 2
                    var path = Path()
                    for (i, p) in route.enumerated() {
                        let x = ox + (p.longitude - minLon) * cosLat * scale
                        let y = oy + (maxLat - p.latitude) * scale
                        if i == 0 { path.move(to: .init(x: x, y: y)) } else { path.addLine(to: .init(x: x, y: y)) }
                    }
                    ctx.stroke(path, with: .color(Theme.accent), style: .init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
            } else {
                Image(systemName: "figure.run").foregroundStyle(.secondary)
            }
        }
    }
}
