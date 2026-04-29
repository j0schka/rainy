import CoreLocation
import Observation

enum AppState {
    case loading
    case raining(stopsIn: Int?)
    case rainIn(Int)
    case noRainSoon
    case error(String)
}

@Observable
class RainViewModel {
    var state: AppState = .loading
    var temperature: Double? = nil
    private var locationManager = LocationManager()
    private var refreshTask: Task<Void, Never>?

    func startUpdating() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.fetchRain()
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    func stopUpdating() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func fetchRain() async {
        guard let coordinate = locationManager.coordinate else {
            let status = locationManager.authorizationStatus
            if status == .denied || status == .restricted {
                state = .error("Location access denied")
            } else {
                state = .loading
                locationManager.refresh()
                try? await Task.sleep(for: .seconds(2))
                await fetchRain()
            }
            return
        }

        do {
            let data = try await fetchWeatherData(
                lat: coordinate.latitude,
                lon: coordinate.longitude
            )
            temperature = data.temperature
            if data.isCurrentlyRaining {
                state = .raining(stopsIn: data.minutesUntilChange)
            } else if let minutes = data.minutesUntilChange {
                state = .rainIn(minutes)
            } else {
                state = .noRainSoon
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
