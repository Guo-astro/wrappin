import Foundation

/// One overseas search candidate. Coordinates are WGS-84 as returned by Geoapify.
struct OverseasPlace: Codable, Hashable, Identifiable, Sendable {
    /// How precisely a result matches a place. A city-level answer to a
    /// street-address query must never look like an exact hit.
    enum Precision: String, Codable, Sendable {
        case building
        case place
        case street
        case area
        case city
        case region
        case country
        case unknown

        init(geoapifyResultType: String?) {
            switch geoapifyResultType {
            case "building": self = .building
            case "amenity": self = .place
            case "street": self = .street
            case "suburb", "district", "postcode": self = .area
            case "city", "county": self = .city
            case "state": self = .region
            case "country": self = .country
            default: self = .unknown
            }
        }

        /// Coarser than a street: only an approximate position.
        var isApproximate: Bool {
            switch self {
            case .building, .place, .street: false
            case .area, .city, .region, .country, .unknown: true
            }
        }
    }

    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let precision: Precision
    let countryCode: String?

    var id: String {
        "\(latitude.bitPattern)-\(longitude.bitPattern)-\(name)"
    }
}

enum OverseasSearchError: Error, Equatable {
    case notConfigured
    case dailyLimitReached
    case serviceUnavailable
    case network
    case invalidResponse
}

/// Limits how many overseas searches one iPhone sends per day, so a single
/// device cannot use up the free quota that every installation shares.
struct OverseasSearchQuota: Codable, Equatable, Sendable {
    static let dailyLimit = 50

    private(set) var day: String
    private(set) var count: Int

    init(day: String = "", count: Int = 0) {
        self.day = day
        self.count = count
    }

    func canSearch(on day: String) -> Bool {
        self.day != day || count < Self.dailyLimit
    }

    mutating func recordSearch(on day: String) {
        if self.day != day {
            self.day = day
            count = 0
        }
        count += 1
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// Keeps recent results on the device so repeating a search does not spend quota.
struct OverseasSearchCache: Codable, Equatable, Sendable {
    static let lifetime: TimeInterval = 7 * 24 * 60 * 60
    static let capacity = 100

    private struct Entry: Codable, Equatable, Sendable {
        let date: Date
        let places: [OverseasPlace]
    }

    private var entries: [String: Entry] = [:]

    /// Bumped whenever the request or result labelling changes, so results
    /// cached by an older version are not reused.
    static let version = 2

    static func key(for query: String) -> String {
        "\(version)|" + query.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    func places(for query: String, at date: Date) -> [OverseasPlace]? {
        guard let entry = entries[Self.key(for: query)],
              date.timeIntervalSince(entry.date) < Self.lifetime else { return nil }
        return entry.places
    }

    mutating func store(_ places: [OverseasPlace], for query: String, at date: Date) {
        entries = entries.filter { date.timeIntervalSince($0.value.date) < Self.lifetime }
        entries[Self.key(for: query)] = Entry(date: date, places: places)
        while entries.count > Self.capacity,
              let oldest = entries.min(by: { $0.value.date < $1.value.date })?.key {
            entries[oldest] = nil
        }
    }
}

/// Searches places outside mainland China with Geoapify, which uses
/// OpenStreetMap data. Mainland Apple Maps data often has no overseas places.
/// Search text leaves the device only when the user runs an overseas search.
enum OverseasPlaceSearch {
    static let resultLimit = 5
    static let infoKey = "WrapPinGeoapifyAPIKey"

    static var apiKey: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
        return trimmed
    }

    static var isConfigured: Bool { apiKey != nil }

    /// Chinese country names at the start of a query. Geoapify does not treat
    /// them as a country restriction, so "法国巴黎" can otherwise return a shop
    /// named 法國巴黎 in another country.
    private static let countryPrefixes: [(name: String, code: String)] = [
        ("日本", "jp"), ("美国", "us"), ("美國", "us"), ("英国", "gb"), ("英國", "gb"),
        ("法国", "fr"), ("法國", "fr"), ("德国", "de"), ("德國", "de"),
        ("意大利", "it"), ("義大利", "it"), ("西班牙", "es"), ("葡萄牙", "pt"),
        ("荷兰", "nl"), ("荷蘭", "nl"), ("比利时", "be"), ("比利時", "be"),
        ("瑞士", "ch"), ("奥地利", "at"), ("奧地利", "at"), ("希腊", "gr"), ("希臘", "gr"),
        ("瑞典", "se"), ("挪威", "no"), ("丹麦", "dk"), ("丹麥", "dk"),
        ("芬兰", "fi"), ("芬蘭", "fi"), ("爱尔兰", "ie"), ("愛爾蘭", "ie"),
        ("捷克", "cz"), ("俄罗斯", "ru"), ("俄羅斯", "ru"), ("土耳其", "tr"),
        ("新加坡", "sg"), ("韩国", "kr"), ("韓國", "kr"), ("泰国", "th"), ("泰國", "th"),
        ("马来西亚", "my"), ("馬來西亞", "my"), ("越南", "vn"),
        ("印度尼西亚", "id"), ("印度尼西亞", "id"), ("印尼", "id"), ("印度", "in"),
        ("菲律宾", "ph"), ("菲律賓", "ph"), ("柬埔寨", "kh"), ("老挝", "la"), ("寮國", "la"),
        ("缅甸", "mm"), ("緬甸", "mm"), ("尼泊尔", "np"), ("尼泊爾", "np"),
        ("斯里兰卡", "lk"), ("斯里蘭卡", "lk"), ("马尔代夫", "mv"), ("馬爾地夫", "mv"),
        ("蒙古", "mn"), ("阿联酋", "ae"), ("阿聯酋", "ae"), ("埃及", "eg"),
        ("澳大利亚", "au"), ("澳大利亞", "au"), ("澳洲", "au"),
        ("新西兰", "nz"), ("新西蘭", "nz"), ("紐西蘭", "nz"), ("加拿大", "ca"),
        ("墨西哥", "mx"), ("巴西", "br"), ("阿根廷", "ar"), ("南非", "za"),
        ("香港", "hk"), ("澳门", "mo"), ("澳門", "mo"), ("台湾", "tw"), ("臺灣", "tw"), ("台灣", "tw")
    ].sorted { $0.name.count > $1.name.count }

    static func countryCode(in query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return countryPrefixes.first { trimmed.hasPrefix($0.name) }?.code
    }

    private static let streetAddressPattern = try! NSRegularExpression(
        pattern: #"\d\s*(号|號|番地|番)|丁目|\d+\s*-\s*\d+|(^|[\s,，])\d+[A-Za-z]?\s+\p{L}"#
    )

    /// Whether the query names a house number, such as "唐宁街10号",
    /// "芝公园4丁目2-8" or "350 Fifth Avenue".
    static func looksLikeStreetAddress(_ query: String) -> Bool {
        streetAddressPattern.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)) != nil
    }

    /// For a house-number query only a building result can be the exact
    /// address. Anything else, even a named place, may be a different place
    /// with a similar number, so it is shown as approximate.
    static func labelled(_ places: [OverseasPlace], for query: String) -> [OverseasPlace] {
        guard looksLikeStreetAddress(query) else { return places }
        return places.map { place in
            guard place.precision != .building else { return place }
            return OverseasPlace(
                name: place.name,
                address: place.address,
                latitude: place.latitude,
                longitude: place.longitude,
                precision: .unknown,
                countryCode: place.countryCode
            )
        }
    }

    static func requestURL(for query: String, apiKey: String) -> URL? {
        var components = URLComponents(string: "https://api.geoapify.com/v1/geocode/search")
        var queryItems = [
            URLQueryItem(name: "text", value: query),
            URLQueryItem(name: "lang", value: "zh"),
            URLQueryItem(name: "limit", value: String(resultLimit)),
            URLQueryItem(name: "format", value: "json")
        ]
        if let countryCode = countryCode(in: query) {
            queryItems.append(URLQueryItem(name: "filter", value: "countrycode:\(countryCode)"))
        }
        queryItems.append(URLQueryItem(name: "apiKey", value: apiKey))
        components?.queryItems = queryItems
        // URLComponents leaves "+" as is, which servers read as a space.
        let encodedQuery = components?.percentEncodedQuery
        components?.percentEncodedQuery = encodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components?.url
    }

    static func places(from data: Data) throws -> [OverseasPlace] {
        guard let response = try? JSONDecoder().decode(GeoapifyResponse.self, from: data) else {
            throw OverseasSearchError.invalidResponse
        }

        return response.results.compactMap { result in
            guard let latitude = result.lat, let longitude = result.lon,
                  (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }

            let line1 = result.address_line1?.trimmed
            let name = result.name?.trimmed ?? line1 ?? result.formatted?.trimmed
            guard let name else { return nil }

            // Prefer the part of the address the name does not already repeat.
            let address = [result.address_line2, result.formatted, line1]
                .compactMap { $0?.trimmed }
                .first { $0 != name } ?? ""

            return OverseasPlace(
                name: name,
                address: address,
                latitude: latitude,
                longitude: longitude,
                precision: Precision(geoapifyResultType: result.result_type),
                countryCode: result.country_code?.trimmed?.uppercased()
            )
        }
    }

    static func search(_ query: String, session: URLSession = .shared) async throws -> [OverseasPlace] {
        guard let apiKey, let url = requestURL(for: query, apiKey: apiKey) else {
            throw OverseasSearchError.notConfigured
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw OverseasSearchError.network
        }

        guard let status = (response as? HTTPURLResponse)?.statusCode else {
            throw OverseasSearchError.invalidResponse
        }
        // 401/403: key rejected or suspended; 429: quota or rate limit; 5xx: outage.
        guard (200..<300).contains(status) else {
            throw OverseasSearchError.serviceUnavailable
        }
        return labelled(try places(from: data), for: query)
    }

    private typealias Precision = OverseasPlace.Precision

    private struct GeoapifyResponse: Decodable {
        let results: [Result]

        // Field names mirror the Geoapify JSON response.
        struct Result: Decodable {
            let name: String?
            let formatted: String?
            let address_line1: String?
            let address_line2: String?
            let lat: Double?
            let lon: Double?
            let result_type: String?
            let country_code: String?
        }
    }
}

private extension String {
    var trimmed: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
