import Compression
import CoreGraphics
import CoreLocation
import Foundation

// MARK: - Public model

struct RadarFrame {
    let timestamp: Date
    let image: CGImage?     // nil when the frame contains no precipitation
}

struct RadarCorners {
    let nw: CLLocationCoordinate2D
    let sw: CLLocationCoordinate2D
    let se: CLLocationCoordinate2D
    let ne: CLLocationCoordinate2D
}

struct RadarMapData {
    let frames: [RadarFrame]
    let corners: RadarCorners
}

// MARK: - Bright Sky /radar response

private struct RadarMapRecord: Decodable {
    let timestamp: Date
    let precipitation5: String   // base64(zlib(int16-LE grid)), row 0 = north
    enum CodingKeys: String, CodingKey {
        case timestamp
        case precipitation5 = "precipitation_5"
    }
}
private struct RadarGeometry: Decodable {
    let coordinates: [[Double]]  // 4 × [lon, lat]: NW, SW, SE, NE
}
private struct RadarMapResponse: Decodable {
    let radar: [RadarMapRecord]
    let geometry: RadarGeometry
    let bbox: [Int]?             // [top, left, bottom, right], pixels, inclusive
}

// MARK: - Fetching

/// Fetches radar frames covering −1 h to +1 h around now, ~150 km in every
/// direction from the given location. One frame per 5 minutes (25 total).
func fetchRadarMap(lat: Double, lon: Double) async throws -> RadarMapData {
    let now = Date()
    var components = URLComponents(string: "https://api.brightsky.dev/radar")!
    components.queryItems = [
        URLQueryItem(name: "lat", value: String(format: "%.4f", lat)),
        URLQueryItem(name: "lon", value: String(format: "%.4f", lon)),
        URLQueryItem(name: "distance", value: "150000"),
        URLQueryItem(name: "format", value: "compressed"),
        URLQueryItem(name: "date", value: radarISO8601(now.addingTimeInterval(-3600))),
        URLQueryItem(name: "last_date", value: radarISO8601(now.addingTimeInterval(3600))),
    ]

    let (data, response) = try await URLSession.shared.data(from: components.url!)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw WeatherError.invalidResponse
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let result = try decoder.decode(RadarMapResponse.self, from: data)

    guard let bbox = result.bbox, bbox.count == 4, !result.radar.isEmpty,
          result.geometry.coordinates.count == 4 else {
        throw WeatherError.noData
    }
    let rows = bbox[2] - bbox[0] + 1
    let cols = bbox[3] - bbox[1] + 1

    let c = result.geometry.coordinates
    let corners = RadarCorners(
        nw: CLLocationCoordinate2D(latitude: c[0][1], longitude: c[0][0]),
        sw: CLLocationCoordinate2D(latitude: c[1][1], longitude: c[1][0]),
        se: CLLocationCoordinate2D(latitude: c[2][1], longitude: c[2][0]),
        ne: CLLocationCoordinate2D(latitude: c[3][1], longitude: c[3][0]))

    let frames = result.radar
        .sorted { $0.timestamp < $1.timestamp }
        .map { record in
            RadarFrame(timestamp: record.timestamp,
                       image: decodeFrameImage(record.precipitation5, rows: rows, cols: cols))
        }
    guard !frames.isEmpty else { throw WeatherError.noData }
    return RadarMapData(frames: frames, corners: corners)
}

private func radarISO8601(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
}

// MARK: - Frame decoding

private func decodeFrameImage(_ base64: String, rows: Int, cols: Int) -> CGImage? {
    guard let compressed = Data(base64Encoded: base64),
          let raw = zlibInflate(compressed, expectedSize: rows * cols * 2)
    else { return nil }

    var hasRain = false
    var pixels = [UInt8](repeating: 0, count: rows * cols * 4)
    raw.withUnsafeBytes { (buf: UnsafeRawBufferPointer) in
        let values = buf.bindMemory(to: UInt16.self)
        for i in 0..<(rows * cols) {
            let value = UInt16(littleEndian: values[i])
            guard value > 0 else { continue }
            hasRain = true
            let (r, g, b, a) = radarColor(for: value)
            // premultiplied RGBA
            pixels[i*4]     = UInt8(Int(r) * Int(a) / 255)
            pixels[i*4 + 1] = UInt8(Int(g) * Int(a) / 255)
            pixels[i*4 + 2] = UInt8(Int(b) * Int(a) / 255)
            pixels[i*4 + 3] = a
        }
    }
    guard hasRain else { return nil }

    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    return CGImage(
        width: cols, height: rows,
        bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: cols * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider, decode: nil, shouldInterpolate: true,
        intent: .defaultIntent)
}

/// Raw values are 0.01 mm per 5 min; ×0.12 → mm/h.
private func radarColor(for value: UInt16) -> (UInt8, UInt8, UInt8, UInt8) {
    let mmPerHour = Double(value) * 0.12
    switch mmPerHour {
    case ..<0.1:   return (0, 0, 0, 0)
    case ..<0.5:   return (135, 206, 250, 110)  // drizzle — pale blue
    case ..<1.0:   return ( 80, 160, 255, 140)
    case ..<2.0:   return ( 30, 110, 255, 170)  // light rain — blue
    case ..<5.0:   return (  0, 200, 120, 185)  // moderate — green
    case ..<10.0:  return (255, 220,   0, 200)  // heavy — yellow
    case ..<30.0:  return (255, 140,   0, 210)  // very heavy — orange
    case ..<100.0: return (235,  40,  40, 220)  // intense — red
    default:       return (180,   0, 180, 230)  // extreme / hail — magenta
    }
}

/// Inflates a zlib stream (RFC 1950: 2-byte header + deflate + 4-byte adler32).
private func zlibInflate(_ data: Data, expectedSize: Int) -> Data? {
    guard data.count > 6 else { return nil }
    let deflate = data.subdata(in: 2..<(data.count - 4))
    var output = Data(count: expectedSize)
    let written = output.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) in
        deflate.withUnsafeBytes { (src: UnsafeRawBufferPointer) in
            compression_decode_buffer(
                dst.bindMemory(to: UInt8.self).baseAddress!, expectedSize,
                src.bindMemory(to: UInt8.self).baseAddress!, deflate.count,
                nil, COMPRESSION_ZLIB)
        }
    }
    guard written == expectedSize else { return nil }
    return output
}
