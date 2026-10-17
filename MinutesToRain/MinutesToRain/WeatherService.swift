import Foundation

struct WeatherData {
    let minutesUntilChange: Int?
    let isCurrentlyRaining: Bool
    let temperature: Double?
    let weatherIcon: String?
    let rainfallIntensity: Double?   // l/m² per 5-min radar frame (= mm); nil when dry
    let source: RainDataSource
}

enum RainDataSource {
    /// DWD radar nowcast via Bright Sky — Germany and neighboring regions.
    case dwdRadar
    /// Open-Meteo 15-minute forecast — worldwide fallback outside DWD coverage.
    case openMeteo

    var label: String {
        switch self {
        case .dwdRadar:  return "Bright Sky · DWD radar · 1 km / 5 min"
        case .openMeteo: return "Open-Meteo · forecast · 15 min"
        }
    }
}

private struct WeatherRecord: Decodable {
    let temperature: Double?
    let icon: String?
}
private struct WeatherResponse: Decodable {
    let weather: [WeatherRecord]
}

private struct RadarRecord: Decodable {
    let timestamp: Date
    let precipitation5: [[Int]]
    enum CodingKeys: String, CodingKey {
        case timestamp
        case precipitation5 = "precipitation_5"
    }
}
private struct LatLonPosition: Decodable {
    let x: Double
    let y: Double
}
private struct RadarResponse: Decodable {
    let radar: [RadarRecord]
    let latlonPosition: LatLonPosition?
    enum CodingKeys: String, CodingKey {
        case radar
        case latlonPosition = "latlon_position"
    }
}

enum WeatherError: Error {
    case invalidResponse
    case noData
}

func fetchWeatherData(lat: Double, lon: Double) async throws -> WeatherData {
    let now = Date()
    // DWD radar coverage is limited to Germany and neighboring regions;
    // outside it, `fetchRadarData` throws and we fall back to Open-Meteo's
    // worldwide 15-minute forecast so the app works everywhere.
    async let radarResult: (minutesUntilChange: Int?, isRaining: Bool, intensity: Double?)? =
        try? fetchRadarData(lat: lat, lon: lon, now: now)
    async let tempResult = try? fetchTemperature(lat: lat, lon: lon, now: now)
    let (radar, weather) = await (radarResult, tempResult)

    if let radar {
        return WeatherData(
            minutesUntilChange: radar.minutesUntilChange,
            isCurrentlyRaining: radar.isRaining,
            temperature: weather?.temperature,
            weatherIcon: weather?.icon,
            rainfallIntensity: radar.intensity,
            source: .dwdRadar
        )
    }

    let fallback = try await fetchOpenMeteo(lat: lat, lon: lon, now: now)
    return WeatherData(
        minutesUntilChange: fallback.minutesUntilChange,
        isCurrentlyRaining: fallback.isRaining,
        temperature: fallback.temperature ?? weather?.temperature,
        weatherIcon: fallback.icon ?? weather?.icon,
        rainfallIntensity: fallback.intensity,
        source: .openMeteo
    )
}

private func fetchRadarData(lat: Double, lon: Double, now: Date) async throws -> (minutesUntilChange: Int?, isRaining: Bool, intensity: Double?) {
    var components = URLComponents(string: "https://api.brightsky.dev/radar")!
    components.queryItems = [
        URLQueryItem(name: "lat", value: String(format: "%.4f", lat)),
        URLQueryItem(name: "lon", value: String(format: "%.4f", lon)),
        URLQueryItem(name: "distance", value: "5000"),
        URLQueryItem(name: "format", value: "plain"),
        URLQueryItem(name: "date", value: iso8601(now)),
    ]

    let (data, response) = try await URLSession.shared.data(from: components.url!)
    let status = (response as? HTTPURLResponse)?.statusCode
    // Bright Sky answers 404 "lat/lon lies outside the radar data range".
    if status == 404 { throw WeatherError.noData }
    guard status == 200 else { throw WeatherError.invalidResponse }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let result = try decoder.decode(RadarResponse.self, from: data)

    guard let pos = result.latlonPosition else { throw WeatherError.noData }
    let x = Int(pos.x.rounded())
    let y = Int(pos.y.rounded())

    func hasRain(in frame: RadarRecord) -> Bool {
        guard y < frame.precipitation5.count,
              x < frame.precipitation5[y].count else { return false }
        return frame.precipitation5[y][x] > 0
    }

    let sorted = result.radar.sorted { $0.timestamp < $1.timestamp }
    let currentFrame = sorted.last(where: { $0.timestamp <= now }) ?? sorted.first
    let isRaining = currentFrame.map(hasRain) ?? false
    let futureFrames = sorted.filter { $0.timestamp > now }

    func radarValue(in frame: RadarRecord) -> Double {
        guard y < frame.precipitation5.count,
              x < frame.precipitation5[y].count else { return 0 }
        return Double(frame.precipitation5[y][x]) / 100.0  // 0.01 mm units → mm = l/m²
    }

    if isRaining {
        let stopFrame = futureFrames.first(where: { !hasRain(in: $0) })
        let minutes = stopFrame.map { max(0, Int($0.timestamp.timeIntervalSince(now) / 60)) }
        let intensity = currentFrame.map(radarValue)
        return (minutes, true, intensity)
    } else {
        let startFrame = futureFrames.first(where: { hasRain(in: $0) })
        let minutes = startFrame.map { max(0, Int($0.timestamp.timeIntervalSince(now) / 60)) }
        let intensity = startFrame.map(radarValue)
        return (minutes, false, intensity)
    }
}

private func fetchTemperature(lat: Double, lon: Double, now: Date) async throws -> (temperature: Double?, icon: String?) {
    var components = URLComponents(string: "https://api.brightsky.dev/weather")!
    components.queryItems = [
        URLQueryItem(name: "lat", value: String(format: "%.4f", lat)),
        URLQueryItem(name: "lon", value: String(format: "%.4f", lon)),
        URLQueryItem(name: "date", value: iso8601(now)),
        URLQueryItem(name: "last_date", value: iso8601(now.addingTimeInterval(3600))),
    ]

    let (data, response) = try await URLSession.shared.data(from: components.url!)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { return (nil, nil) }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let result = try? decoder.decode(WeatherResponse.self, from: data)
    let record = result?.weather.first
    return (record?.temperature, record?.icon)
}

// MARK: - Open-Meteo (worldwide fallback)

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let temperature2m: Double?
        let weatherCode: Int?
        let isDay: Int?
        let precipitation: Double?
        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
            case isDay = "is_day"
            case precipitation
        }
    }
    struct Minutely15: Decodable {
        let time: [TimeInterval]
        let precipitation: [Double?]
    }
    let current: Current?
    let minutely15: Minutely15?
    enum CodingKeys: String, CodingKey {
        case current
        case minutely15 = "minutely_15"
    }
}

private func fetchOpenMeteo(lat: Double, lon: Double, now: Date) async throws
    -> (minutesUntilChange: Int?, isRaining: Bool, intensity: Double?, temperature: Double?, icon: String?)
{
    var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
    components.queryItems = [
        URLQueryItem(name: "latitude", value: String(format: "%.4f", lat)),
        URLQueryItem(name: "longitude", value: String(format: "%.4f", lon)),
        URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day,precipitation"),
        URLQueryItem(name: "minutely_15", value: "precipitation"),
        URLQueryItem(name: "past_minutely_15", value: "1"),
        URLQueryItem(name: "forecast_minutely_15", value: "9"),
        URLQueryItem(name: "timeformat", value: "unixtime"),
        URLQueryItem(name: "timezone", value: "GMT"),
    ]

    let (data, response) = try await URLSession.shared.data(from: components.url!)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw WeatherError.invalidResponse
    }
    let result = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

    // Each 15-minute value is the precipitation sum of the preceding
    // 15 minutes, so a slot "starts" 15 minutes before its timestamp.
    let slots: [(start: Date, mm: Double)] = result.minutely15.map { m in
        zip(m.time, m.precipitation).map { (Date(timeIntervalSince1970: $0 - 900), $1 ?? 0) }
    } ?? []
    let threshold = 0.05  // mm per 15 min — ignore rounding noise
    let currentSlot = slots.last(where: { $0.start <= now })
    let isRaining = (result.current?.precipitation ?? currentSlot?.mm ?? 0) > threshold
    let futureSlots = slots.filter { $0.start > now }

    // Convert mm per 15 min to the mm per 5 min the UI expects.
    let minutes: Int?
    let intensity: Double?
    if isRaining {
        let stop = futureSlots.first(where: { $0.mm <= threshold })
        minutes = stop.map { max(0, Int($0.start.timeIntervalSince(now) / 60)) }
        intensity = (currentSlot?.mm ?? result.current?.precipitation).map { $0 / 3 }
    } else {
        let start = futureSlots.first(where: { $0.mm > threshold })
        minutes = start.map { max(0, Int($0.start.timeIntervalSince(now) / 60)) }
        intensity = start.map { $0.mm / 3 }
    }

    let icon = result.current?.weatherCode.map {
        brightSkyIcon(forWMOCode: $0, isDay: (result.current?.isDay ?? 1) == 1)
    }
    return (minutes, isRaining, intensity, result.current?.temperature2m, icon)
}

/// Maps WMO weather codes onto Bright Sky's icon names used by the UI.
private func brightSkyIcon(forWMOCode code: Int, isDay: Bool) -> String {
    switch code {
    case 0:            return isDay ? "clear-day" : "clear-night"
    case 1, 2:         return isDay ? "partly-cloudy-day" : "partly-cloudy-night"
    case 3:            return "cloudy"
    case 45, 48:       return "fog"
    case 51...55:      return "drizzle"
    case 56, 57, 66, 67: return "sleet"
    case 61...65, 80...82: return "rain"
    case 71...77, 85, 86:  return "snow"
    case 95...99:      return "thunderstorm"
    default:           return "cloudy"
    }
}

private func iso8601(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
}
