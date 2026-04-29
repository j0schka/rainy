import Foundation

struct WeatherData {
    let minutesUntilRain: Int?
    let temperature: Double?
}

private struct WeatherRecord: Decodable {
    let temperature: Double?
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
    async let minutesResult = fetchRadarMinutes(lat: lat, lon: lon, now: now)
    async let tempResult = fetchTemperature(lat: lat, lon: lon, now: now)
    let (minutes, temperature) = try await (minutesResult, tempResult)
    return WeatherData(minutesUntilRain: minutes, temperature: temperature)
}

private func fetchRadarMinutes(lat: Double, lon: Double, now: Date) async throws -> Int? {
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

    let futureFrames = result.radar.filter { $0.timestamp > now }
    guard let rainFrame = futureFrames.first(where: { frame in
        guard y < frame.precipitation5.count,
              x < frame.precipitation5[y].count else { return false }
        return frame.precipitation5[y][x] > 0
    }) else {
        return nil
    }

    return max(0, Int(rainFrame.timestamp.timeIntervalSince(now) / 60))
}

private func fetchTemperature(lat: Double, lon: Double, now: Date) async throws -> Double? {
    var components = URLComponents(string: "https://api.brightsky.dev/weather")!
    components.queryItems = [
        URLQueryItem(name: "lat", value: String(format: "%.4f", lat)),
        URLQueryItem(name: "lon", value: String(format: "%.4f", lon)),
        URLQueryItem(name: "date", value: iso8601(now)),
        URLQueryItem(name: "last_date", value: iso8601(now.addingTimeInterval(3600))),
    ]

    let (data, response) = try await URLSession.shared.data(from: components.url!)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let result = try? decoder.decode(WeatherResponse.self, from: data)
    return result?.weather.first?.temperature
}

private func iso8601(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
}
