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
    @State private var data: RadarMapData?
    @State private var errorText: String?
    @State private var frameIndex: Double = 0
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            Color.radarBgDeep.ignoresSafeArea()

            if let data, let coordinate {
                RadarMapView(data: data,
                             center: coordinate,
                             frameIndex: Int(frameIndex))
                    .ignoresSafeArea()
                controls(for: data)
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
            guard isPlaying, let data else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                frameIndex = Double((Int(frameIndex) + 1) % data.frames.count)
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
            frameIndex = Double(nowIndex(in: result.frames))
            data = result
        } catch WeatherError.noData {
            // The German Weather Service's radar only covers Germany and
            // neighboring regions; this is expected outside that footprint.
            errorText = "Rain radar isn't available at this location.\nCoverage is limited to Germany and neighboring regions."
        } catch {
            errorText = "Radar data unavailable. Please try again."
        }
    }

    /// Index of the frame closest to the current time.
    private func nowIndex(in frames: [RadarFrame]) -> Int {
        let now = Date()
        return frames.indices.min(by: {
            abs(frames[$0].timestamp.timeIntervalSince(now)) <
            abs(frames[$1].timestamp.timeIntervalSince(now))
        }) ?? 0
    }

    // MARK: Controls

    private func controls(for data: RadarMapData) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 14) {
                timeLabel(for: data)

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
                               in: 0...Double(data.frames.count - 1),
                               step: 1,
                               onEditingChanged: { editing in
                                   if editing { isPlaying = false }
                               })
                            .tint(Color.radarCyan)
                        HStack {
                            Text("−1 h")
                            Spacer()
                            Text("now")
                            Spacer()
                            Text("+1 h")
                        }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                    }
                }

                legend
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

    private func timeLabel(for data: RadarMapData) -> some View {
        let frame = data.frames[Int(frameIndex)]
        let minutes = Int((frame.timestamp.timeIntervalSinceNow / 60).rounded())
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
            Text(frame.timestamp, format: .dateTime.hour().minute())
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

// MARK: - MapKit wrapper

private struct RadarMapView: UIViewRepresentable {
    let data: RadarMapData
    let center: CLLocationCoordinate2D
    let frameIndex: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.overrideUserInterfaceStyle = .dark
        map.pointOfInterestFilter = .excludingAll
        map.showsUserLocation = true
        map.setRegion(
            MKCoordinateRegion(center: center,
                               latitudinalMeters: 180_000,
                               longitudinalMeters: 180_000),
            animated: false)
        context.coordinator.currentImage = data.frames[frameIndex].image
        map.addOverlay(RadarOverlay(corners: data.corners))
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let image = data.frames[frameIndex].image
        context.coordinator.currentImage = image
        context.coordinator.renderer?.image = image
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var currentImage: CGImage?
        weak var renderer: RadarOverlayRenderer?

        func mapView(_ mapView: MKMapView,
                     rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = RadarOverlayRenderer(overlay: overlay)
            renderer.image = currentImage
            self.renderer = renderer
            return renderer
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
