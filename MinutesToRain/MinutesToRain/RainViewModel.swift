import CoreLocation
import Observation
import UserNotifications

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
    var weatherIcon: String? = nil
    var rainfallIntensity: Double? = nil
    private var locationManager = LocationManager()
    private var refreshTask: Task<Void, Never>?

    func startUpdating() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
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
                try? await Task.sleep(for: .seconds(1))
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
            weatherIcon = data.weatherIcon
            rainfallIntensity = data.rainfallIntensity
            let center = UNUserNotificationCenter.current()
            if data.isCurrentlyRaining {
                state = .raining(stopsIn: data.minutesUntilChange)
                center.removePendingNotificationRequests(withIdentifiers: ["rain-alert"])
            } else if let minutes = data.minutesUntilChange {
                state = .rainIn(minutes)
                scheduleRainNotification(in: minutes, using: center)
            } else {
                state = .noRainSoon
                center.removePendingNotificationRequests(withIdentifiers: ["rain-alert"])
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func scheduleRainNotification(in minutes: Int, using center: UNUserNotificationCenter) {
        guard minutes > 15 else { return }
        center.removePendingNotificationRequests(withIdentifiers: ["rain-alert"])
        let content = UNMutableNotificationContent()
        content.title = "Rain in 15 minutes"
        content.body = "Grab an umbrella — rain is on its way."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: Double(minutes - 15) * 60, repeats: false)
        center.add(UNNotificationRequest(
            identifier: "rain-alert", content: content, trigger: trigger))
    }
}
