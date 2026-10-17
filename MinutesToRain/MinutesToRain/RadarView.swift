import MapKit
import SwiftUI

private extension Color {
    static let radarBgDeep  = Color(red: 18/255, green:  8/255, blue:  46/255)
    static let radarCyan    = Color(red: 91/255, green: 200/255, blue: 245/255)
}

// MARK: - Fullscreen radar

struct RadarView: View {
    let coordinate: CLLocationCoordinate2D?

    @Environment(\.dismiss) private var dismiss
    @State private var content: RadarContent?
    @State private var errorText: String?
    @State private var frameIndex: Double = 0
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            Color.radarBgDeep.ignoresSafeArea()

            if let content, let coordinate {
                RadarMapView(content: content,
                             center: coordinate,
                             frameIndex: Int(frameIndex))
                    .ignoresSafeArea()
                controls(for: content)
            } else if let errorText {
                errorView(errorText)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }

            closeButton
        }
        .task { await load() }
        .task(id: isPlaying) {
            guard isPlaying, let content else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                frameIndex = Double((Int(frameIndex) + 1) % content.timestamps.count)
            }
        }
    }

    private func load() async {
        guard let coordinate else {
            errorText = "Location unavailable"
            return
        }
        do {
            let result = try await fetchRadarMap(
                lat: coordinate.latitude, lon: coordinate.longitude)
            show(.dwd(result))
        } catch {
            // The German Weather Service's radar only covers Germany and
            // neighboring regions; elsewhere, use RainViewer's global composite.
            do {
                show(.tiles(try await fetchTileRadar()))
            } catch {
                errorText = "Radar data unavailable. Please try again."
            }
        }
    }

    private func show(_ result: RadarContent) {
        frameIndex = Double(nowIndex(in: result.timestamps))
        content = result
    }

    /// Index of the frame closest to the current time.
    private func nowIndex(in timestamps: [Date]) -> Int {
        let now = Date()
        return timestamps.indices.min(by: {
            abs(timestamps[$0].timeIntervalSince(now)) <
            abs(timestamps[$1].timeIntervalSince(now))
        }) ?? 0
    }

    // MARK: Controls

    private func controls(for content: RadarContent) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 14) {
                timeLabel(for: content)

                HStack(spacing: 16) {
                    Button {
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.12), in: Circle())
                    }

                    VStack(spacing: 4) {
                        Slider(value: $frameIndex,
                               in: 0...Double(max(1, content.timestamps.count - 1)),
                               step: 1,
                               onEditingChanged: { editing in
                                   if editing { isPlaying = false }
                               })
                            .tint(Color.radarCyan)
                        HStack {
                            Text(relativeLabel(content.timestamps.first))
                            Spacer()
                            Text(relativeLabel(content.timestamps.last))
                        }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                    }
                }

                legend
                Text(content.attribution)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
            .background(.ultraThinMaterial.opacity(0.85))
            .background(Color.radarBgDeep.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private func relativeLabel(_ date: Date?) -> String {
        guard let date else { return "" }
        let minutes = Int((date.timeIntervalSinceNow / 60).rounded())
        if abs(minutes) <= 5 { return "now" }
        let text = abs(minutes) >= 60
            ? "\(Int((Double(abs(minutes)) / 60).rounded())) h"
            : "\(abs(minutes)) min"
        return (minutes < 0 ? "−" : "+") + text
    }

    private func timeLabel(for content: RadarContent) -> some View {
        let timestamp = content.timestamps[Int(frameIndex)]
        let minutes = Int((timestamp.timeIntervalSinceNow / 60).rounded())
        let badge: String
        let badgeColor: Color
        if minutes < -2 {
            badge = "\(minutes) min"
            badgeColor = .white.opacity(0.5)
        } else if minutes > 2 {
            badge = "+\(minutes) min · forecast"
            badgeColor = .radarCyan
        } else {
            badge = "now"
            badgeColor = .radarCyan
        }
        return HStack(spacing: 10) {
            Text(timestamp, format: .dateTime.hour().minute())
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(badge)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(badgeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.white.opacity(0.10), in: Capsule())
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Text("light")
            LinearGradient(
                colors: [
                    Color(red: 135/255, green: 206/255, blue: 250/255),
                    Color(red:  30/255, green: 110/255, blue: 255/255),
                    Color(red:   0/255, green: 200/255, blue: 120/255),
                    Color(red: 255/255, green: 220/255, blue:   0/255),
                    Color(red: 255/255, green: 140/255, blue:   0/255),
                    Color(red: 235/255, green:  40/255, blue:  40/255),
                ],
                startPoint: .leading, endPoint: .trailing)
                .frame(height: 6)
                .clipShape(Capsule())
            Text("heavy")
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.45))
    }

    private func errorView(_ text: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.5))
            Text(text)
                .font(.system(size: 17, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") {
                errorText = nil
                Task { await load() }
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.radarCyan)
        }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .padding(.trailing, 20)
            }
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Radar content

enum RadarContent {
    /// DWD composite decoded on-device (Germany and neighboring regions).
    case dwd(RadarMapData)
    /// RainViewer global composite, rendered as map tiles.
    case tiles(TileRadarData)

    var timestamps: [Date] {
        switch self {
        case .dwd(let data):   return data.frames.map(\.timestamp)
        case .tiles(let data): return data.frames.map(\.timestamp)
        }
    }

    var attribution: String {
        switch self {
        case .dwd:   return "Radar: Deutscher Wetterdienst via Bright Sky"
        case .tiles: return "Radar: RainViewer"
        }
    }
}

// MARK: - MapKit wrapper

private struct RadarMapView: UIViewRepresentable {
    let content: RadarContent
    let center: CLLocationCoordinate2D
    let frameIndex: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.overrideUserInterfaceStyle = .dark
        map.pointOfInterestFilter = .excludingAll
        map.showsUserLocation = true
        context.coordinator.frameIndex = frameIndex

        switch content {
        case .dwd(let data):
            map.setRegion(
                MKCoordinateRegion(center: center,
                                   latitudinalMeters: 180_000,
                                   longitudinalMeters: 180_000),
                animated: false)
            context.coordinator.currentImage = data.frames[frameIndex].image
            map.addOverlay(RadarOverlay(corners: data.corners))
        case .tiles(let data):
            // RainViewer tiles top out at zoom 7 (~1 km/px), so start wider.
            map.setRegion(
                MKCoordinateRegion(center: center,
                                   latitudinalMeters: 400_000,
                                   longitudinalMeters: 400_000),
                animated: false)
            // One overlay per frame; only the current one is visible, so
            // scrubbing and playback don't reload tiles.
            let overlays = data.frames.enumerated().map { index, frame in
                RainViewerTileOverlay(host: data.host, path: frame.path, index: index)
            }
            map.addOverlays(overlays, level: .aboveRoads)
        }
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.frameIndex = frameIndex
        switch content {
        case .dwd(let data):
            let image = data.frames[frameIndex].image
            coordinator.currentImage = image
            coordinator.renderer?.image = image
        case .tiles:
            for (index, renderer) in coordinator.tileRenderers {
                renderer.alpha = index == frameIndex ? 0.8 : 0
            }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var currentImage: CGImage?
        var frameIndex = 0
        weak var renderer: RadarOverlayRenderer?
        var tileRenderers: [Int: MKTileOverlayRenderer] = [:]

        func mapView(_ mapView: MKMapView,
                     rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tiles = overlay as? RainViewerTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tiles)
                renderer.alpha = tiles.index == frameIndex ? 0.8 : 0
                tileRenderers[tiles.index] = renderer
                return renderer
            }
            let renderer = RadarOverlayRenderer(overlay: overlay)
            renderer.image = currentImage
            self.renderer = renderer
            return renderer
        }
    }
}

// MARK: - RainViewer tiles

/// RainViewer serves tiles up to zoom 7 only. Deeper zoom levels are
/// produced by cropping and upscaling the covering zoom-7 tile.
private final class RainViewerTileOverlay: MKTileOverlay {
    static let maxSourceZoom = 7
    let host: String
    let path: String
    let index: Int

    init(host: String, path: String, index: Int) {
        self.host = host
        self.path = path
        self.index = index
        super.init(urlTemplate: nil)
        canReplaceMapContent = false
        tileSize = CGSize(width: 256, height: 256)
    }

    private func sourceURL(z: Int, x: Int, y: Int) -> URL {
        // 512 px source tiles, color scheme 2, smoothed, snow shown.
        URL(string: "\(host)\(path)/512/\(z)/\(x)/\(y)/2/1_1.png")!
    }

    override func loadTile(at tilePath: MKTileOverlayPath,
                           result: @escaping (Data?, Error?) -> Void) {
        let dz = max(0, tilePath.z - Self.maxSourceZoom)
        let url = sourceURL(z: tilePath.z - dz, x: tilePath.x >> dz, y: tilePath.y >> dz)
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data, dz > 0 else { return result(data, error) }
            result(Self.crop(data, dz: dz, x: tilePath.x, y: tilePath.y), nil)
        }.resume()
    }

    private static func crop(_ data: Data, dz: Int, x: Int, y: Int) -> Data? {
        guard let source = UIImage(data: data)?.cgImage else { return nil }
        let divisions = 1 << dz
        let side = CGFloat(source.width) / CGFloat(divisions)
        let rect = CGRect(x: CGFloat(x % divisions) * side,
                          y: CGFloat(y % divisions) * side,
                          width: side, height: side).integral
        guard let piece = source.cropping(to: rect) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: 256, height: 256)
        return UIGraphicsImageRenderer(size: size, format: format).pngData { _ in
            UIImage(cgImage: piece).draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Radar overlay

private final class RadarOverlay: NSObject, MKOverlay {
    let corners: RadarCorners
    let boundingMapRect: MKMapRect

    init(corners: RadarCorners) {
        self.corners = corners
        let points = [corners.nw, corners.sw, corners.se, corners.ne]
            .map(MKMapPoint.init)
        let xs = points.map(\.x), ys = points.map(\.y)
        boundingMapRect = MKMapRect(
            x: xs.min()!, y: ys.min()!,
            width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
        super.init()
    }

    var coordinate: CLLocationCoordinate2D {
        MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate
    }
}

private final class RadarOverlayRenderer: MKOverlayRenderer {
    var image: CGImage? {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        guard let image, let overlay = overlay as? RadarOverlay else { return }
        let w = CGFloat(image.width)
        let h = CGFloat(image.height)

        // Map the image rect onto the parallelogram spanned by the radar grid
        // corners. The DE1200 grid is polar stereographic, so its corners are
        // not axis-aligned in map space; an affine fit keeps alignment errors
        // below the radar's own 1 km resolution at this scale.
        let p0 = point(for: MKMapPoint(overlay.corners.nw))
        let pX = point(for: MKMapPoint(overlay.corners.ne))
        let pY = point(for: MKMapPoint(overlay.corners.sw))
        let transform = CGAffineTransform(
            a: (pX.x - p0.x) / w, b: (pX.y - p0.y) / w,
            c: (pY.x - p0.x) / h, d: (pY.y - p0.y) / h,
            tx: p0.x, ty: p0.y)

        ctx.saveGState()
        ctx.concatenate(transform)
        ctx.translateBy(x: 0, y: h)
        ctx.scaleBy(x: 1, y: -1)
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        ctx.restoreGState()
    }
}
