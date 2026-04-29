import SwiftUI

// MARK: - Weather icon mapping

private enum WeatherIcon {
    case clearDay, clearNight, partlyCloudy, cloudy, other

    init(from string: String?) {
        switch string {
        case "clear-day":                              self = .clearDay
        case "clear-night":                            self = .clearNight
        case "partly-cloudy-day", "partly-cloudy-night": self = .partlyCloudy
        case "cloudy":                                 self = .cloudy
        default:                                       self = .other
        }
    }

    var isSunny: Bool { self == .clearDay || self == .clearNight }
    var isPartlyCloudy: Bool { self == .partlyCloudy }
}

// MARK: - Design tokens

private extension Color {
    static let bgDeep      = Color(red: 18/255,  green:  8/255, blue:  46/255)
    static let bgTop       = Color(red: 42/255,  green: 18/255, blue:  96/255)
    static let rainCyan    = Color(red: 91/255,  green: 200/255, blue: 245/255)
    static let periwinkle  = Color(red: 123/255, green: 143/255, blue: 255/255)
    static let cloudLight  = Color(red: 232/255, green: 238/255, blue: 255/255)
    static let cloudMid    = Color(red: 188/255, green: 197/255, blue: 238/255)
    static let cloudDark   = Color(red: 138/255, green: 150/255, blue: 208/255)
    static let dropLight   = Color(red: 168/255, green: 220/255, blue: 255/255)
    static let dropDark    = Color(red:  75/255, green: 168/255, blue: 232/255)
    static let sunLight    = Color(red: 255/255, green: 244/255, blue: 194/255)
    static let sunMid      = Color(red: 255/255, green: 216/255, blue:  74/255)
    static let sunDeep     = Color(red: 255/255, green: 168/255, blue:  32/255)
    static let sunGlow     = Color(red: 255/255, green: 210/255, blue:  80/255)
}

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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            background
            if case .raining = viewModel.state { RainView() }
            mainContent
            GlassCardView(temperature: viewModel.temperature, state: viewModel.state)
        }
        .onAppear { viewModel.startUpdating() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { Task { await viewModel.fetchRain() } }
        }
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            RadialGradient(
                colors: [.bgTop, .bgDeep],
                center: .top,
                startRadius: 0,
                endRadius: UIScreen.main.bounds.height * 0.75
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [.periwinkle.opacity(0.18), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 160
            )
            .frame(width: 320, height: 320)
            .offset(y: -UIScreen.main.bounds.height * 0.3)
            .ignoresSafeArea()
        }
    }

    // MARK: Main content

    private var mainContent: some View {
        VStack(spacing: 0) {
            AppHeaderView()
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
            case .clearDay, .clearNight: SunView()
            case .partlyCloudy:          PartlyCloudyView()
            default:                     CloudView(mode: .calm)
            }
        case .loading:  CloudView(mode: .loading)
        case .raining:  CloudView(mode: .raining)
        case .rainIn:   CloudView(mode: .rainIn)
        case .error:    CloudView(mode: .error)
        }
    }

    private var glowColor: Color {
        switch viewModel.state {
        case .raining:
            return .rainCyan.opacity(glowPulsed ? 0.70 : 0.40)
        case .noRainSoon:
            let icon = WeatherIcon(from: viewModel.weatherIcon)
            if icon.isSunny       { return .sunGlow.opacity(glowPulsed ? 0.55 : 0.30) }
            if icon.isPartlyCloudy { return .sunGlow.opacity(glowPulsed ? 0.28 : 0.14) }
            return .clear
        default:
            return .clear
        }
    }

    private func startGlowAnimation() {
        glowPulsed = false
        let duration: Double
        switch viewModel.state {
        case .raining:    duration = 2.0
        case .noRainSoon:
            let icon = WeatherIcon(from: viewModel.weatherIcon)
            duration = (icon.isSunny || icon.isPartlyCloudy) ? 3.0 : 0
        default:          duration = 0
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
        case .loading:
            return (nil, nil)
        case .rainIn(let m):
            return ("\(m)", "min")
        case .raining(let stopsIn):
            if let stopsIn { return ("\(stopsIn)", "min") }
            return ("—", nil)
        case .noRainSoon:
            return ("—", nil)
        case .error:
            return ("?", nil)
        }
    }
}

// MARK: - Header

private struct AppHeaderView: View {
    var body: some View {
        Text("MinutesToRain")
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.top, 58)
    }
}

// MARK: - Cloud illustration

private let cloudGradient = LinearGradient(
    colors: [.cloudLight, .cloudMid, .cloudDark],
    startPoint: .top, endPoint: .bottom
)
private let dropGradient = LinearGradient(
    colors: [.dropLight, .dropDark],
    startPoint: .top, endPoint: .bottom
)

struct CloudView: View {
    enum Mode { case loading, raining, rainIn, error, calm }
    let mode: Mode

    @State private var isPulsing = false

    private let animatedDrops: [(x: CGFloat, y: CGFloat, delay: Double)] = [
        (-30, 55, 0.00), (-5, 65, 0.15), (20, 55, 0.30),
        (-18, 75, 0.10), ( 8, 81, 0.25),
    ]
    private let staticDrops: [(x: CGFloat, y: CGFloat)] = [
        (-22, 55), (0, 65), (22, 55),
    ]

    var body: some View {
        ZStack {
            Ellipse()
                .fill(mode == .raining ? Color.rainCyan.opacity(0.12) : Color.periwinkle.opacity(0.10))
                .frame(width: 160, height: 40)
                .offset(y: 55)

            ZStack {
                Circle().frame(width: 80).offset(x: 30, y: 5).opacity(0.85)
                Circle().frame(width: 68).offset(x: -35, y: 12).opacity(0.90)
                Circle().frame(width: 92).offset(x: 0, y: -12)
                RoundedRectangle(cornerRadius: 20).frame(width: 148, height: 40).offset(y: 17)
            }
            .foregroundStyle(cloudGradient)
            .opacity(mode == .error ? 0.60 : 1.0)

            Ellipse()
                .fill(.white.opacity(0.55))
                .frame(width: 56, height: 28)
                .offset(x: -13, y: -25)
                .opacity(mode == .error ? 0.60 : 1.0)

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
        .animation(mode == .loading ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true) : .default, value: isPulsing)
        .onAppear { if mode == .loading { isPulsing = true } }
    }
}

private struct RainDropShape: View {
    var body: some View {
        ZStack {
            Ellipse().fill(dropGradient).frame(width: 9, height: 18)
            Ellipse().fill(.white.opacity(0.5)).frame(width: 4, height: 6).offset(x: -1, y: -4)
        }
    }
}

private struct AnimatedRainDrop: View {
    let delay: Double
    @State private var phase: Double = 0

    var body: some View {
        RainDropShape()
            .offset(y: phase * 28)
            .opacity(phase < 0.2 ? phase / 0.2 : phase > 0.8 ? (1 - phase) / 0.2 : 1.0)
            .onAppear {
                withAnimation(.easeIn(duration: 1.0).repeatForever(autoreverses: false).delay(delay)) {
                    phase = 1.0
                }
            }
    }
}

// MARK: - Sun illustration

struct SunView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.sunGlow.opacity(0.4), .clear],
                                     center: .center, startRadius: 0, endRadius: 72))
                .frame(width: 144, height: 144)

            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let rotation = (t / 12).truncatingRemainder(dividingBy: 1) * 360
                    let cx = size.width / 2, cy = size.height / 2
                    for i in 0..<12 {
                        let angle = (Double(i) * 30 + rotation) * .pi / 180
                        var path = Path()
                        path.move(to: CGPoint(x: cx + cos(angle) * 52, y: cy + sin(angle) * 52))
                        path.addLine(to: CGPoint(x: cx + cos(angle) * 68, y: cy + sin(angle) * 68))
                        ctx.stroke(path, with: .color(.sunMid.opacity(0.8)),
                                   style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    }
                }
                .frame(width: 180, height: 180)
            }

            Circle()
                .fill(RadialGradient(colors: [.sunLight, .sunMid, .sunDeep],
                                     center: UnitPoint(x: 0.4, y: 0.35),
                                     startRadius: 0, endRadius: 44))
                .frame(width: 88, height: 88)

            Ellipse().fill(.white.opacity(0.45)).frame(width: 32, height: 20).offset(x: -12, y: -16)

            Ellipse()
                .fill(Color(red: 1, green: 200/255, blue: 60/255).opacity(0.10))
                .frame(width: 120, height: 24)
                .offset(y: 66)
        }
        .frame(width: 260, height: 200)
    }
}

// MARK: - Partly cloudy illustration

struct PartlyCloudyView: View {
    var body: some View {
        ZStack {
            // soft sun glow behind cloud
            Circle()
                .fill(RadialGradient(colors: [.sunGlow.opacity(0.35), .clear],
                                     center: .center, startRadius: 0, endRadius: 56))
                .frame(width: 112, height: 112)
                .offset(x: 56, y: 28)

            // sun disc (lower-right, partially hidden behind cloud)
            Circle()
                .fill(RadialGradient(colors: [.sunLight, .sunMid, .sunDeep],
                                     center: UnitPoint(x: 0.4, y: 0.35),
                                     startRadius: 0, endRadius: 30))
                .frame(width: 60, height: 60)
                .offset(x: 56, y: 28)

            // main cloud (upper-left), slightly smaller than full CloudView
            ZStack {
                Circle().frame(width: 58).offset(x: 22, y: 4).opacity(0.85)
                Circle().frame(width: 50).offset(x: -26, y: 9).opacity(0.90)
                Circle().frame(width: 68).offset(x: 0, y: -9)
                RoundedRectangle(cornerRadius: 15).frame(width: 110, height: 30).offset(y: 13)
            }
            .foregroundStyle(cloudGradient)
            .offset(x: -28, y: -18)

            // specular highlight on cloud
            Ellipse()
                .fill(.white.opacity(0.50))
                .frame(width: 38, height: 18)
                .offset(x: -33, y: -42)
        }
        .frame(width: 260, height: 200)
    }
}

// MARK: - Rain streak overlay

struct RainView: View {
    private struct Drop {
        let x, phaseOffset, speed, length, opacity, drift: Double
    }

    private static let drops: [Drop] = (0..<90).map { _ in
        Drop(
            x:           .random(in: 0...1),
            phaseOffset: .random(in: 0...1),
            speed:       .random(in: 0.8...1.6),
            length:      .random(in: 18...38),
            opacity:     .random(in: 0.12...0.30),
            drift:       .random(in: 0.06...0.12)
        )
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
                    path.move(to: CGPoint(x: x, y: y))
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
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 28, bottomLeading: 0, bottomTrailing: 0, topTrailing: 28))
        )
    }
}

#Preview {
    ContentView()
}
