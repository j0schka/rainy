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
            VStack(spacing: 24) {
                circleContent
                temperatureLabel
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
    private var temperatureLabel: some View {
        if let temp = viewModel.temperature {
            Text(String(format: "%.0f°C", temp))
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        } else {
            Color.clear.frame(height: 28)
        }
    }

    @ViewBuilder
    private var circleContent: some View {
        switch viewModel.state {
        case .loading:
            loadingCircle
        case .raining:
            labelCircle(number: "0", sub: "min")
        case .rainIn(let minutes):
            labelCircle(number: "\(minutes)", sub: "min")
        case .noRainSoon:
            labelCircle(number: "—", sub: nil)
        case .error:
            labelCircle(number: "?", sub: nil)
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

#Preview {
    ContentView()
}
