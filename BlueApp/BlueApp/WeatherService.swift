import Foundation

struct WeatherRecord: Decodable {
    let timestamp: Date
    let precipitation: Double?
    let temperature: Double?
}

struct WeatherResponse: Decodable {
    let weather: [WeatherRecord]
}

enum WeatherError: Error {
    case invalidResponse
    case noData
}

struct WeatherData {
    let minutesUntilRain: Int?
    let temperature: Double?
}

func fetchWeatherData(lat: Double, lon: Double) async throws -> WeatherData {
    let now = Date()
    let twoHoursLater = now.addingTimeInterval(2 * 3600)

    var components = URLComponents(string: "https://api.brightsky.dev/weather")!
    components.queryItems = [
        URLQueryItem(name: "lat", value: String(format: "%.4f", lat)),
        URLQueryItem(name: "lon", value: String(format: "%.4f", lon)),
        URLQueryItem(name: "date", value: iso8601(now)),
        URLQueryItem(name: "last_date", value: iso8601(twoHoursLater)),
    ]

    let (data, response) = try await URLSession.shared.data(from: components.url!)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw WeatherError.invalidResponse
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let result = try decoder.decode(WeatherResponse.self, from: data)

    let temperature = result.weather.first?.temperature

    let futureRecords = result.weather.filter { $0.timestamp >= now }
    guard let rainRecord = futureRecords.first(where: { ($0.precipitation ?? 0) > 0 }) else {
        return WeatherData(minutesUntilRain: nil, temperature: temperature)
    }

    let minutes = max(0, Int(rainRecord.timestamp.timeIntervalSince(now) / 60))
    return WeatherData(minutesUntilRain: minutes, temperature: temperature)
}

private func iso8601(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
}
