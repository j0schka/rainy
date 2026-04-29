import CoreLocation
import Observation

enum AppState {
    case loading
    case raining
    case rainIn(Int)
    case noRainSoon
    case error(String)
}

@Observable
class RainViewModel {
    var state: AppState = .loading
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
            let minutes = try await fetchMinutesUntilRain(
                lat: coordinate.latitude,
                lon: coordinate.longitude
            )
            if let minutes {
                state = minutes == 0 ? .raining : .rainIn(minutes)
            } else {
                state = .noRainSoon
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
