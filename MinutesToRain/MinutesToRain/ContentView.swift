import SwiftUI

// MARK: - Weather icon mapping

private enum WeatherIcon {
    case clearDay, clearNight
    case partlyCloudyDay, partlyCloudyNight
    case cloudy, rain, sleet, snow, wind, fog, other

    init(from string: String?) {
        switch string {
        case "clear-day":                              self = .clearDay
        case "clear-night":                            self = .clearNight
        case "partly-cloudy-day":                      self = .partlyCloudyDay
        case "partly-cloudy-night":                    self = .partlyCloudyNight
        case "cloudy":                                 self = .cloudy
        case "rain", "drizzle":                        self = .rain
        case "sleet":                                  self = .sleet
        case "snow":                                   self = .snow
        case "wind":                                   self = .wind
        case "fog":                                    self = .fog
        default:                                       self = .other
        }
    }
}

// MARK: - Design tokens

private extension Color {
    static let bgDeep          = Color(red: 18/255,  green:  8/255, blue:  46/255)
    static let bgTop           = Color(red: 42/255,  green: 18/255, blue:  96/255)
    static let rainCyan        = Color(red: 91/255,  green: 200/255, blue: 245/255)
    static let periwinkle      = Color(red: 123/255, green: 143/255, blue: 255/255)
    // Cloud — day
    static let cloudLight      = Color(red: 240/255, green: 244/255, blue: 255/255)
    static let cloudMid        = Color(red: 200/255, green: 210/255, blue: 242/255)
    static let cloudDark       = Color(red: 138/255, green: 150/255, blue: 208/255)
    // Cloud — night
    static let cloudNightLight = Color(red: 200/255, green: 208/255, blue: 240/255)
    static let cloudNightMid   = Color(red: 136/255, green: 150/255, blue: 204/255)
    static let cloudNightDark  = Color(red:  80/255, green:  88/255, blue: 136/255)
    // Rain drop
    static let dropLight       = Color(red: 192/255, green: 232/255, blue: 255/255)
    static let dropDark        = Color(red:  74/255, green: 184/255, blue: 232/255)
    // Sleet
    static let sleetLight      = Color(red: 208/255, green: 232/255, blue: 255/255)
    static let sleetDark       = Color(red: 128/255, green: 184/255, blue: 216/255)
    // Snow
    static let snowLight       = Color(red: 238/255, green: 238/255, blue: 255/255)
    static let snowMid         = Color(red: 160/255, green: 176/255, blue: 224/255)
    // Sun
    static let sunLight        = Color(red: 255/255, green: 244/255, blue: 194/255)
    static let sunMid          = Color(red: 255/255, green: 216/255, blue:  74/255)
    static let sunDeep         = Color(red: 255/255, green: 168/255, blue:  32/255)
    static let sunGlow         = Color(red: 255/255, green: 210/255, blue:  80/255)
    // Moon
    static let moonLight       = Color(red: 232/255, green: 236/255, blue: 255/255)
    static let moonMid         = Color(red: 176/255, green: 184/255, blue: 232/255)
    static let moonDark        = Color(red: 120/255, green: 128/255, blue: 184/255)
}

private let cloudDayGrad = LinearGradient(
    colors: [.cloudLight, .cloudMid, .cloudDark],
    startPoint: .topLeading, endPoint: .bottomTrailing)
private let cloudNightGrad = LinearGradient(
    colors: [.cloudNightLight, .cloudNightMid, .cloudNightDark],
    startPoint: .topLeading, endPoint: .bottomTrailing)
private let dropGrad = LinearGradient(
    colors: [.dropLight, .dropDark], startPoint: .top, endPoint: .bottom)
private let sleetGrad = LinearGradient(
    colors: [.sleetLight, .sleetDark], startPoint: .top, endPoint: .bottom)
private let snowGrad = RadialGradient(
    colors: [.snowLight, .snowMid], center: .center, startRadius: 0, endRadius: 6)

// MARK: - App state condition text

private extension AppState {
    var conditionText: String {
        switch self {
        case .loading:    return "locating…"
        case .rainIn:     return "rain approaching"
        case .raining:    return "currently raining"
        case .noRainSoon: return "no rain in sight"
        case .error:      return "check location"
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @State private var viewModel = RainViewModel()
    @State private var glowPulsed = false
    @State private var showRadar = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            background
            if case .raining = viewModel.state { RainView() }
            mainContent
            GlassCardView(temperature: viewModel.temperature,
                          intensity: viewModel.rainfallIntensity,
                          state: viewModel.state)
        }
        .onAppear { viewModel.startUpdating() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { Task { await viewModel.fetchRain() } }
        }
        .fullScreenCover(isPresented: $showRadar) {
            RadarView(coordinate: viewModel.coordinate)
        }
    }

    private var radarButton: some View {
        Button {
            showRadar = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("Regenradar")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Color(red: 18/255, green: 8/255, blue: 46/255))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(red: 91/255, green: 200/255, blue: 245/255), in: Capsule())
        }
        .disabled(viewModel.coordinate == nil)
        .opacity(viewModel.coordinate == nil ? 0.4 : 1.0)
    }

    private var background: some View {
        ZStack {
            RadialGradient(
                colors: [.bgTop, .bgDeep],
                center: .top, startRadius: 0,
                endRadius: UIScreen.main.bounds.height * 0.75)
            .ignoresSafeArea()
            RadialGradient(
                colors: [.periwinkle.opacity(0.18), .clear],
                center: .center, startRadius: 0, endRadius: 160)
            .frame(width: 320, height: 320)
            .offset(y: -UIScreen.main.bounds.height * 0.3)
            .ignoresSafeArea()
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            AppHeaderView(isRaining: isRaining)
            Spacer()
            illustrationView
                .shadow(color: glowColor, radius: 35, y: 20)
                .onAppear { startGlowAnimation() }
                .onChange(of: viewModel.state.conditionText) { startGlowAnimation() }
            numberStack
                .padding(.top, -8)
            Text(viewModel.state.conditionText)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.60))
                .padding(.top, 6)
            radarButton
                .padding(.top, 18)
            Spacer()
            Color.clear.frame(height: 160)
        }
    }

    @ViewBuilder
    private var illustrationView: some View {
        switch viewModel.state {
        case .noRainSoon:
            let icon = WeatherIcon(from: viewModel.weatherIcon)
            switch icon {
            case .clearDay:          SunView()
            case .clearNight:        ClearNightView()
            case .partlyCloudyDay:   PartlyCloudyDayView()
            case .partlyCloudyNight: PartlyCloudyNightView()
            case .cloudy:            CloudyView()
            case .wind:              WindView()
            case .fog:               FogView()
            case .snow:              SnowView()
            case .sleet:             SleetView()
            default:                 CloudyView()
            }
        case .loading:  CloudView(mode: .loading)
        case .raining:  CloudView(mode: .raining)
        case .rainIn:   CloudView(mode: .rainIn)
        case .error:    CloudView(mode: .error)
        }
    }

    private var isRaining: Bool {
        if case .raining = viewModel.state { return true }
        return false
    }

    private var glowColor: Color {
        switch viewModel.state {
        case .raining:
            return .rainCyan.opacity(glowPulsed ? 0.70 : 0.40)
        case .noRainSoon:
            let icon = WeatherIcon(from: viewModel.weatherIcon)
            switch icon {
            case .clearDay:
                return .sunGlow.opacity(glowPulsed ? 0.55 : 0.30)
            case .clearNight:
                return .moonMid.opacity(glowPulsed ? 0.40 : 0.20)
            case .partlyCloudyDay:
                return .sunGlow.opacity(glowPulsed ? 0.28 : 0.14)
            case .partlyCloudyNight:
                return .moonMid.opacity(glowPulsed ? 0.20 : 0.10)
            case .rain, .snow, .sleet:
                return .rainCyan.opacity(glowPulsed ? 0.30 : 0.15)
            case .cloudy, .wind, .fog, .other:
                return .periwinkle.opacity(glowPulsed ? 0.20 : 0.10)
            }
        default:
            return .clear
        }
    }

    private func startGlowAnimation() {
        glowPulsed = false
        let duration: Double
        switch viewModel.state {
        case .raining: duration = 2.0
        case .noRainSoon:
            let icon = WeatherIcon(from: viewModel.weatherIcon)
            switch icon {
            case .clearDay, .clearNight:             duration = 3.0
            case .partlyCloudyDay, .partlyCloudyNight: duration = 3.5
            case .cloudy, .other:                    duration = 0
            default:                                 duration = 2.5
            }
        default: duration = 0
        }
        guard duration > 0 else { return }
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            glowPulsed = true
        }
    }

    @ViewBuilder
    private var numberStack: some View {
        let (num, sub) = numberAndSub
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            if let num {
                Text(num)
                    .font(.system(size: 88, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                if let sub {
                    Text(sub)
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.80))
                        .padding(.bottom, 14)
                }
            } else {
                Color.clear.frame(height: 88)
            }
        }
    }

    private var numberAndSub: (String?, String?) {
        switch viewModel.state {
        case .loading:              return (nil, nil)
        case .rainIn(let m):        return ("\(m)", "min")
        case .raining(let s):
            if let s { return ("\(s)", "min") }
            return ("—", nil)
        case .noRainSoon:           return ("—", nil)
        case .error:                return ("?", nil)
        }
    }
}

// MARK: - Header

private struct AppHeaderView: View {
    let isRaining: Bool

    var body: some View {
        Text(isRaining ? "Minutes To Rain Stop" : "Minutes To Rain")
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.top, 58)
            .animation(.default, value: isRaining)
    }
}

// MARK: - Shared cloud shape
// Coordinates: canvas origin (0,0) top-left, 260×200 frame.
// SwiftUI ZStack offset = (canvas_x − 130, canvas_y − 100).

struct CloudBaseView: View {
    var cx: CGFloat = 130   // cloud centre in canvas coords
    var cy: CGFloat = 110
    var scale: CGFloat = 1
    var night: Bool = false
    var opacity: Double = 1

    var body: some View {
        let g = night ? cloudNightGrad : cloudDayGrad
        let ox = cx - 130
        let oy = cy - 100
        ZStack {
            Circle().fill(g).opacity(0.88).frame(width: 104*scale).offset(x: ox+38*scale, y: oy-18*scale)
            Circle().fill(g).opacity(0.92).frame(width:  88*scale).offset(x: ox-32*scale, y: oy-10*scale)
            Circle().fill(g)              .frame(width: 116*scale).offset(x: ox+8*scale, y: oy-36*scale)
            Circle().fill(g).opacity(0.80).frame(width:  68*scale).offset(x: ox+58*scale, y: oy-4*scale)
            RoundedRectangle(cornerRadius: 21*scale).fill(g)
                .frame(width: 128*scale, height: 42*scale)
                .offset(x: ox+18*scale, y: oy+7*scale)
            Ellipse().fill(.white.opacity(0.50))
                .frame(width: 76*scale, height: 36*scale)
                .offset(x: ox-4*scale, y: oy-54*scale)
        }
        .opacity(opacity)
    }
}

// MARK: - Clear day (sun)

struct SunView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.sunGlow.opacity(0.45), .clear],
                                     center: .center, startRadius: 0, endRadius: 68))
                .frame(width: 136, height: 136)
                .offset(y: -5)

            TimelineView(.animation) { tl in
                Canvas { ctx, _ in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let rot = (t / 18).truncatingRemainder(dividingBy: 1) * 2 * .pi
                    for i in 0..<12 {
                        let a = Double(i) * .pi / 6 + rot
                        var p = Path()
                        p.move(to: CGPoint(x: 130 + cos(a)*50, y: 95 + sin(a)*50))
                        p.addLine(to: CGPoint(x: 130 + cos(a)*65, y: 95 + sin(a)*65))
                        ctx.stroke(p, with: .color(.sunMid.opacity(0.85)),
                                   style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    }
                }
                .frame(width: 260, height: 200)
            }

            Circle()
                .fill(RadialGradient(colors: [.sunLight, .sunMid, .sunDeep],
                                     center: UnitPoint(x: 0.4, y: 0.35),
                                     startRadius: 0, endRadius: 40))
                .frame(width: 80, height: 80)
                .offset(y: -5)

            Ellipse().fill(.white.opacity(0.45)).frame(width: 28, height: 16).offset(x: -12, y: -20)

            Ellipse()
                .fill(Color.sunGlow.opacity(0.10))
                .frame(width: 110, height: 22)
                .offset(y: 58)
        }
        .frame(width: 260, height: 200)
    }
}

// MARK: - Clear night (moon + stars)

struct ClearNightView: View {
    private let starData: [(x: CGFloat, y: CGFloat, r: CGFloat, period: Double, phase: Double)] = [
        (40, 30, 2.2, 2.8, 0.0), (200, 45, 1.5, 3.6, 1.1),
        (220, 120, 1.8, 4.0, 2.2), (50, 140, 1.4, 2.4, 3.3),
        (170, 160, 1.6, 3.2, 4.4), (100, 25, 1.3, 2.0, 5.5), (230, 75, 1.7, 3.8, 0.6),
    ]

    var body: some View {
        ZStack {
            TimelineView(.animation) { tl in
                Canvas { ctx, _ in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    for s in starData {
                        let a = 0.20 + 0.70 * (sin(t * 2 * .pi / s.period + s.phase) + 1) / 2
                        var p = Path()
                        p.addEllipse(in: CGRect(x: s.x-s.r, y: s.y-s.r, width: s.r*2, height: s.r*2))
                        ctx.fill(p, with: .color(.white.opacity(a)))
                    }
                }
                .frame(width: 260, height: 200)
            }

            // Moon glow
            Circle()
                .fill(RadialGradient(colors: [.moonMid.opacity(0.40), .clear],
                                     center: .center, startRadius: 0, endRadius: 50))
                .frame(width: 100, height: 100)
                .offset(y: -8)

            // Moon disc — canvas (130,92) → SwiftUI (0,-8)
            Circle()
                .fill(RadialGradient(colors: [.moonLight, .moonMid, .moonDark],
                                     center: UnitPoint(x: 0.4, y: 0.35),
                                     startRadius: 0, endRadius: 42))
                .frame(width: 84, height: 84)
                .offset(y: -8)

            // Crescent overlay — canvas (152,80) → SwiftUI (22,-20)
            Circle()
                .fill(Color.bgDeep)
                .frame(width: 72, height: 72)
                .offset(x: 22, y: -20)

            // Craters — canvas (112,88)→(-18,-12) and (124,105)→(-6,5)
            Circle().fill(.white.opacity(0.10)).frame(width: 10).offset(x: -18, y: -12)
            Circle().fill(.white.opacity(0.08)).frame(width: 7).offset(x: -6, y: 5)

            Ellipse()
                .fill(Color.moonMid.opacity(0.08))
                .frame(width: 84, height: 18)
                .offset(y: 58)
        }
        .frame(width: 260, height: 200)
    }
}

// MARK: - Partly cloudy day

struct PartlyCloudyDayView: View {
    var body: some View {
        ZStack {
            // Sun glow — canvas (82,72) → SwiftUI (-48,-28)
            Circle()
                .fill(RadialGradient(colors: [.sunGlow.opacity(0.35), .clear],
                                     center: .center, startRadius: 0, endRadius: 36))
                .frame(width: 72, height: 72)
                .offset(x: -48, y: -28)

            // Rotating rays — drawn in canvas space
            TimelineView(.animation) { tl in
                Canvas { ctx, _ in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let rot = (t / 18).truncatingRemainder(dividingBy: 1) * 2 * .pi
                    for i in 0..<8 {
                        let a = Double(i) * .pi / 4 + rot
                        var p = Path()
                        p.move(to:    CGPoint(x: 82 + cos(a)*36, y: 72 + sin(a)*36))
                        p.addLine(to: CGPoint(x: 82 + cos(a)*46, y: 72 + sin(a)*46))
                        ctx.stroke(p, with: .color(.sunMid.opacity(0.75)),
                                   style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    }
                }
                .frame(width: 260, height: 200)
            }

            // Sun disc
            Circle()
                .fill(RadialGradient(colors: [.sunLight, .sunMid, .sunDeep],
                                     center: UnitPoint(x: 0.4, y: 0.35),
                                     startRadius: 0, endRadius: 26))
                .frame(width: 52, height: 52)
                .offset(x: -48, y: -28)

            // Cloud in front — spec: cx=108, cy=116, scale=0.9
            CloudBaseView(cx: 108, cy: 116, scale: 0.9)

            Ellipse()
                .fill(Color.rainCyan.opacity(0.08))
                .frame(width: 130, height: 26)
                .offset(x: 25, y: 58)
        }
        .frame(width: 260, height: 200)
    }
}

// MARK: - Partly cloudy night

struct PartlyCloudyNightView: View {
    private let starData: [(x: CGFloat, y: CGFloat, r: CGFloat, period: Double, phase: Double)] = [
        (40, 35, 1.8, 2.0, 0.0), (215, 50, 1.4, 2.5, 1.3),
        (220, 110, 1.6, 3.0, 2.6), (45, 120, 1.3, 2.2, 3.9),
    ]

    var body: some View {
        ZStack {
            TimelineView(.animation) { tl in
                Canvas { ctx, _ in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    for s in starData {
                        let a = 0.15 + 0.65 * (sin(t * 2 * .pi / s.period + s.phase) + 1) / 2
                        var p = Path()
                        p.addEllipse(in: CGRect(x: s.x-s.r, y: s.y-s.r, width: s.r*2, height: s.r*2))
                        ctx.fill(p, with: .color(.white.opacity(a)))
                    }
                }
                .frame(width: 260, height: 200)
            }

            // Moon glow — canvas (80,72) → SwiftUI (-50,-28)
            Circle()
                .fill(RadialGradient(colors: [.moonMid.opacity(0.35), .clear],
                                     center: .center, startRadius: 0, endRadius: 40))
                .frame(width: 80, height: 80)
                .offset(x: -50, y: -28)

            // Moon disc
            Circle()
                .fill(RadialGradient(colors: [.moonLight, .moonMid, .moonDark],
                                     center: UnitPoint(x: 0.4, y: 0.35),
                                     startRadius: 0, endRadius: 32))
                .frame(width: 64, height: 64)
                .offset(x: -50, y: -28)

            // Crescent overlay — canvas (98,62) → SwiftUI (-32,-38)
            Circle()
                .fill(Color.bgDeep)
                .frame(width: 54, height: 54)
                .offset(x: -32, y: -38)

            // Cloud in front — night gradient, spec: cx=108, cy=116, scale=0.9
            CloudBaseView(cx: 108, cy: 116, scale: 0.9, night: true)

            Ellipse()
                .fill(Color.moonMid.opacity(0.07))
                .frame(width: 130, height: 26)
                .offset(x: 25, y: 58)
        }
        .frame(width: 260, height: 200)
    }
}

// MARK: - Cloudy (two-layer depth cloud)

struct CloudyView: View {
    var body: some View {
        ZStack {
            CloudBaseView(cx: 145, cy: 105, scale: 0.78, opacity: 0.55)
            CloudBaseView(cx: 95,  cy: 110, scale: 0.92)
            Ellipse()
                .fill(Color.periwinkle.opacity(0.09))
                .frame(width: 150, height: 28)
                .offset(x: 45, y: 58)
        }
        .frame(width: 260, height: 200)
    }
}

// MARK: - Cloud (rain states / loading / error)

struct CloudView: View {
    enum Mode { case loading, raining, rainIn, error }
    let mode: Mode

    @State private var isPulsing = false

    private let animatedDrops: [(x: CGFloat, y: CGFloat, delay: Double)] = [
        (-22, 62, 0.00), (-2, 72, 0.12), (20, 62, 0.25),
        (-12, 82, 0.08), (10, 86, 0.20),
    ]
    private let staticDrops: [(x: CGFloat, y: CGFloat)] = [
        (-22, 55), (0, 65), (22, 55),
    ]

    var body: some View {
        ZStack {
            Ellipse()
                .fill(mode == .raining ? Color.rainCyan.opacity(0.12) : Color.periwinkle.opacity(0.10))
                .frame(width: 160, height: 40)
                .offset(y: 60)

            CloudBaseView(cx: 130, cy: 108, scale: 1.0, opacity: mode == .error ? 0.60 : 1.0)

            if mode == .raining {
                ForEach(Array(animatedDrops.enumerated()), id: \.offset) { _, drop in
                    AnimatedRainDrop(delay: drop.delay)
                        .offset(x: drop.x, y: drop.y)
                }
            }
            if mode == .rainIn {
                ForEach(Array(staticDrops.enumerated()), id: \.offset) { _, drop in
                    RainDropShape().offset(x: drop.x, y: drop.y).opacity(0.5)
                }
            }
        }
        .frame(width: 260, height: 200)
        .opacity(mode == .loading ? (isPulsing ? 0.35 : 1.0) : 1.0)
        .animation(mode == .loading ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true) : .default,
                   value: isPulsing)
        .onAppear { if mode == .loading { isPulsing = true } }
    }
}

// MARK: - Snow

struct SnowView: View {
    private let flakes: [(x: CGFloat, y: CGFloat, r: CGFloat, delay: Double)] = [
        (-25, 64, 8, 0.00), (-2, 74, 7, 0.18), (22, 63, 8, 0.35),
        (-15, 86, 6, 0.10), (10, 88, 7, 0.26),
    ]

    var body: some View {
        ZStack {
            CloudBaseView(cx: 100, cy: 105, scale: 0.95)

            Ellipse()
                .fill(Color.snowMid.opacity(0.10))
                .frame(width: 136, height: 26)
                .offset(x: 18, y: 58)

            ForEach(Array(flakes.enumerated()), id: \.offset) { _, f in
                AnimatedSnowflake(r: f.r, delay: f.delay)
                    .offset(x: f.x, y: f.y)
            }
        }
        .frame(width: 260, height: 200)
    }
}

// MARK: - Sleet

struct SleetView: View {
    var body: some View {
        ZStack {
            CloudBaseView(cx: 100, cy: 105, scale: 0.95)

            Ellipse()
                .fill(Color.sleetDark.opacity(0.10))
                .frame(width: 136, height: 26)
                .offset(x: 18, y: 58)

            // drop, pellet, drop, pellet, drop
            AnimatedRainDrop(delay: 0.00).offset(x: -22, y: 62)
            AnimatedIcePellet(delay: 0.15).offset(x: -2, y: 66)
            AnimatedRainDrop(delay: 0.30).offset(x: 20, y: 62)
            AnimatedIcePellet(delay: 0.08).offset(x: -12, y: 82)
            AnimatedRainDrop(delay: 0.22).offset(x: 10, y: 84)
        }
        .frame(width: 260, height: 200)
    }
}

// MARK: - Wind

struct WindView: View {
    private let lines: [(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat,
                         ex: CGFloat, ey: CGFloat, w: CGFloat, op: Double, delay: Double)] = [
        (40, 82, 188, 82, 205, 75, 3.5, 0.55, 0.00),
        (28, 100, 198, 100, 210, 100, 4.0, 0.65, 0.10),
        (36, 118, 190, 118, 206, 125, 3.5, 0.55, 0.20),
        (55, 136, 175, 136, 188, 143, 3.0, 0.40, 0.15),
        (48, 64,  160, 64,  172, 57,  2.5, 0.35, 0.05),
    ]

    var body: some View {
        ZStack {
            TimelineView(.animation) { tl in
                Canvas { ctx, _ in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    for l in lines {
                        let phase: Double = t * 2 * Double.pi / 2.5 + l.delay * 2 * Double.pi
                        let sway: CGFloat = CGFloat(4.0 + 4.0 * sin(phase))
                        let col = Color.white.opacity(0.75 * l.op)
                        let style = StrokeStyle(lineWidth: l.w, lineCap: .round)
                        var line = Path()
                        line.move(to:    CGPoint(x: l.x1 + sway, y: l.y1))
                        line.addLine(to: CGPoint(x: l.x2 + sway, y: l.y2))
                        ctx.stroke(line, with: .color(col), style: style)
                        var curl = Path()
                        curl.move(to: CGPoint(x: l.x2 + sway, y: l.y2))
                        curl.addQuadCurve(
                            to: CGPoint(x: l.ex + sway, y: l.ey),
                            control: CGPoint(x: l.ex + sway, y: l.y2))
                        ctx.stroke(curl, with: .color(col.opacity(0.7)), style: style)
                    }
                }
                .frame(width: 260, height: 200)
            }

            Ellipse()
                .fill(Color.periwinkle.opacity(0.08))
                .frame(width: 140, height: 20)
                .offset(y: 65)
        }
        .frame(width: 260, height: 200)
    }
}

// MARK: - Fog

struct FogView: View {
    private let bars: [(y: CGFloat, w: CGFloat, x: CGFloat, op: Double, delay: Double)] = [
        (70, 160, 50, 0.45, 0.00),
        (88, 185, 38, 0.55, 0.30),
        (106, 175, 44, 0.60, 0.60),
        (124, 165, 48, 0.50, 0.90),
        (142, 145, 58, 0.38, 0.45),
        (160, 125, 68, 0.28, 0.15),
    ]

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, _ in
                let t = tl.date.timeIntervalSinceReferenceDate
                for (i, b) in bars.enumerated() {
                    let period = 2.8 + Double(i) * 0.4
                    let drift  = 3.0 + 3.0 * sin(t * 2 * .pi / period + b.delay * 2 * .pi)
                    let alpha  = b.op * (0.65 + 0.35 * (sin(t * 2 * .pi / period + b.delay * 2 * .pi) + 1) / 2)
                    let rect   = CGRect(x: b.x + drift, y: b.y - 5, width: b.w, height: 10)
                    let path   = Path(roundedRect: rect, cornerRadius: 5)
                    ctx.fill(path, with: .color(Color(red: 200/255, green: 210/255, blue: 240/255).opacity(alpha)))
                }
                var glow = Path()
                glow.addEllipse(in: CGRect(x: 65, y: 170, width: 130, height: 18))
                ctx.fill(glow, with: .color(Color.periwinkle.opacity(0.07)))
            }
        }
        .frame(width: 260, height: 200)
    }
}

// MARK: - Shared drop / snowflake shapes

private struct RainDropShape: View {
    var body: some View {
        ZStack {
            Ellipse().fill(dropGrad).frame(width: 11, height: 22)
            Ellipse().fill(.white.opacity(0.52)).frame(width: 4, height: 8).offset(x: -1.5, y: -4)
        }
        .shadow(color: Color.dropDark.opacity(0.4), radius: 8)
    }
}

private struct AnimatedRainDrop: View {
    let delay: Double
    @State private var phase: Double = 0

    var body: some View {
        RainDropShape()
            .offset(y: phase * 22)
            .opacity(phase < 0.2 ? phase / 0.2 : phase > 0.8 ? (1 - phase) / 0.2 : 0.92)
            .onAppear {
                withAnimation(.easeIn(duration: 1.0).repeatForever(autoreverses: false).delay(delay)) {
                    phase = 1.0
                }
            }
    }
}

private struct SnowflakeShape: View {
    let r: CGFloat
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            for i in 0..<6 {
                let a = Double(i) * .pi / 3
                var p = Path()
                p.move(to: c)
                p.addLine(to: CGPoint(x: c.x + cos(a)*Double(r), y: c.y + sin(a)*Double(r)))
                ctx.stroke(p, with: .color(.snowLight), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }
            var dot = Path()
            dot.addEllipse(in: CGRect(x: c.x-2, y: c.y-2, width: 4, height: 4))
            ctx.fill(dot, with: .color(.snowMid))
        }
        .frame(width: r*2+4, height: r*2+4)
        .shadow(color: Color.snowMid.opacity(0.5), radius: 5)
    }
}

private struct AnimatedSnowflake: View {
    let r: CGFloat
    let delay: Double
    @State private var phase: Double = 0

    var body: some View {
        SnowflakeShape(r: r)
            .offset(y: phase * 28)
            .opacity(phase < 0.2 ? phase / 0.2 : phase > 0.8 ? (1 - phase) / 0.2 : 0.85)
            .onAppear {
                withAnimation(.easeIn(duration: 1.2).repeatForever(autoreverses: false).delay(delay)) {
                    phase = 1.0
                }
            }
    }
}

private struct IcePelletShape: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.snowLight, .snowMid],
                                     center: UnitPoint(x: 0.3, y: 0.3),
                                     startRadius: 0, endRadius: 6))
                .frame(width: 12, height: 12)
            Circle().fill(.white.opacity(0.6)).frame(width: 4).offset(x: -2, y: -2)
        }
        .shadow(color: Color.snowMid.opacity(0.5), radius: 5)
    }
}

private struct AnimatedIcePellet: View {
    let delay: Double
    @State private var phase: Double = 0

    var body: some View {
        IcePelletShape()
            .offset(y: phase * 22)
            .opacity(phase < 0.2 ? phase / 0.2 : phase > 0.8 ? (1 - phase) / 0.2 : 0.90)
            .onAppear {
                withAnimation(.easeIn(duration: 0.9).repeatForever(autoreverses: false).delay(delay)) {
                    phase = 1.0
                }
            }
    }
}

// MARK: - Rain streak overlay

struct RainView: View {
    private struct Drop {
        let x, phaseOffset, speed, length, opacity, drift: Double
    }

    private static let drops: [Drop] = (0..<90).map { _ in
        Drop(x: .random(in: 0...1), phaseOffset: .random(in: 0...1),
             speed: .random(in: 0.8...1.6), length: .random(in: 18...38),
             opacity: .random(in: 0.12...0.30), drift: .random(in: 0.06...0.12))
    }

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for d in Self.drops {
                    let phase = ((t / d.speed) + d.phaseOffset).truncatingRemainder(dividingBy: 1)
                    let y = phase * (size.height + d.length) - d.length
                    let x = d.x * size.width + y * d.drift
                    var path = Path()
                    path.move(to:    CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + d.length * d.drift, y: y + d.length))
                    ctx.stroke(path, with: .color(.rainCyan.opacity(d.opacity)), lineWidth: 1.5)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass bottom card

private struct GlassCardView: View {
    let temperature: Double?
    let intensity: Double?
    let state: AppState

    private var showData: Bool {
        if case .loading = state { return false }
        if case .error   = state { return false }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TEMPERATURE")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .kerning(1.0)
                    if showData, let temp = temperature {
                        Text("\(Int(temp.rounded()))°C")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    } else {
                        Text("—")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                Spacer()
                if showData, let mm = intensity {
                    VStack(alignment: .center, spacing: 2) {
                        Text("RAIN INTENSITY")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                            .kerning(1.0)
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text(mm < 10 ? String(format: "%.1f", mm) : "\(Int(mm))")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("l/m²")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.bottom, 5)
                        }
                    }
                    Spacer()
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text("UPDATES")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .kerning(1.0)
                    Text("every 5 min")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(height: 1)
                .padding(.vertical, 16)

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.rainCyan)
                    .frame(width: 8, height: 8)
                    .shadow(color: .rainCyan, radius: 4)
                Text("Bright Sky · DWD radar · 1 km / 5 min")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 28)
        .padding(.bottom, 36)
        .background(.ultraThinMaterial.opacity(0.6))
        .background(.white.opacity(0.07))
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
        }
        .clipShape(
            UnevenRoundedRectangle(cornerRadii:
                .init(topLeading: 28, bottomLeading: 0, bottomTrailing: 0, topTrailing: 28))
        )
    }
}

#Preview {
    ContentView()
}
