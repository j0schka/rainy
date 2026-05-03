import Foundation

struct WeatherData {
    let minutesUntilChange: Int?
    let isCurrentlyRaining: Bool
    let temperature: Double?
    let weatherIcon: String?
    let rainfallIntensity: Double?   // l/m² per 5-min radar frame (= mm); nil when dry
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
    async let radarResult = fetchRadarData(lat: lat, lon: lon, now: now)
    async let tempResult = fetchTemperature(lat: lat, lon: lon, now: now)
    let (radar, weather) = try await (radarResult, tempResult)
    return WeatherData(
        minutesUntilChange: radar.minutesUntilChange,
        isCurrentlyRaining: radar.isRaining,
        temperature: weather.temperature,
        weatherIcon: weather.icon,
        rainfallIntensity: radar.intensity
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
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw WeatherError.invalidResponse
    }

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
        return Double(frame.precipitation5[y][x]) / 10.0  // 1/10 mm → mm = l/m²
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

private func iso8601(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
}
