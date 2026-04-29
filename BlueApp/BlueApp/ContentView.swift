import SwiftUI

private let darkNavy = Color(red: 0.04, green: 0.09, blue: 0.18)
private let lightBlue = Color(red: 0.40, green: 0.65, blue: 0.95)
private let circleSize: CGFloat = 260

struct ContentView: View {
    @State private var viewModel = RainViewModel()
    @State private var isPulsing = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            darkNavy.ignoresSafeArea()
            if case .raining = viewModel.state {
                RainView()
            }
            VStack(spacing: 24) {
                circleContent
                temperatureLabel
                noRainLabel
            }
        }
        .onAppear { viewModel.startUpdating() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.fetchRain() }
            }
        }
    }

    @ViewBuilder
    private var circleContent: some View {
        switch viewModel.state {
        case .loading:
            loadingCircle
        case .raining(let stopsIn):
            if let stopsIn {
                labelCircle(number: "\(stopsIn)", sub: "min")
            } else {
                labelCircle(number: "—", sub: nil)
            }
        case .rainIn(let minutes):
            labelCircle(number: "\(minutes)", sub: "min")
        case .noRainSoon:
            labelCircle(number: "—", sub: nil)
        case .error:
            labelCircle(number: "?", sub: nil)
        }
    }

    @ViewBuilder
    private var noRainLabel: some View {
        if case .noRainSoon = viewModel.state {
            Text("no rain in sight")
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        } else {
            Color.clear.frame(height: 18)
        }
    }

    @ViewBuilder
    private var temperatureLabel: some View {
        if let temp = viewModel.temperature {
            Text(String(format: "%.0f°C", temp))
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        } else {
            Color.clear.frame(height: 28)
        }
    }

    private var loadingCircle: some View {
        Circle()
            .fill(lightBlue)
            .frame(width: circleSize, height: circleSize)
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }

    private func labelCircle(number: String, sub: String?) -> some View {
        Circle()
            .fill(lightBlue)
            .frame(width: circleSize, height: circleSize)
            .overlay {
                VStack(spacing: 2) {
                    Text(number)
                        .font(.system(size: 90, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    if let sub {
                        Text(sub)
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
    }
}

// MARK: - Rain animation

private struct RainDrop {
    let x: CGFloat
    let phaseOffset: Double
    let speed: Double
    let length: CGFloat
    let opacity: Double
    let drift: CGFloat
}

struct RainView: View {
    private static let drops: [RainDrop] = (0..<90).map { _ in
        RainDrop(
            x: CGFloat.random(in: 0...1),
            phaseOffset: Double.random(in: 0...1),
            speed: Double.random(in: 0.8...1.6),
            length: CGFloat.random(in: 18...38),
            opacity: Double.random(in: 0.15...0.35),
            drift: CGFloat.random(in: 0.06...0.12)
        )
    }

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for drop in Self.drops {
                    let phase = ((t / drop.speed) + drop.phaseOffset)
                        .truncatingRemainder(dividingBy: 1.0)
                    let y = CGFloat(phase) * (size.height + drop.length) - drop.length
                    let x = drop.x * size.width + y * drop.drift

                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + drop.length * drop.drift,
                                            y: y + drop.length))
                    ctx.stroke(
                        path,
                        with: .color(.white.opacity(drop.opacity)),
                        lineWidth: 1.5
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
