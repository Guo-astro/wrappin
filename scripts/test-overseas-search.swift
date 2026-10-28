import Foundation

// Compile with the production OverseasPlaceSearch.swift to verify request
// construction, response parsing, precision labels, caching and the per-device
// daily limit. Makes no network requests.
@main
struct OverseasSearchCheck {
    static func main() {
        checkRequest()
        checkParsing()
        checkPrecision()
        checkCountryFilter()
        checkStreetAddressLabelling()
        checkQuota()
        checkCache()
        print("Overseas search checks passed")
    }

    static func checkRequest() {
        let url = OverseasPlaceSearch.requestURL(for: "东京塔 & 芝公园", apiKey: "test-key")!
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        precondition(url.host == "api.geoapify.com" && url.scheme == "https")
        precondition(url.path == "/v1/geocode/search")
        precondition(value("text") == "东京塔 & 芝公园")
        precondition(value("lang") == "zh")
        precondition(value("limit") == "5")
        precondition(value("format") == "json")
        precondition(value("apiKey") == "test-key")
        // The ampersand in the query must not split into another parameter.
        precondition(items.count == 5)

        let plus = OverseasPlaceSearch.requestURL(for: "C+ Tower", apiKey: "k")!
        precondition(plus.absoluteString.contains("text=C%2B%20Tower"), plus.absoluteString)

        // A leading country name restricts results to that country; the text is kept.
        let paris = OverseasPlaceSearch.requestURL(for: "法国巴黎", apiKey: "k")!
        let parisItems = URLComponents(url: paris, resolvingAgainstBaseURL: false)!.queryItems!
        precondition(parisItems.first { $0.name == "filter" }?.value == "countrycode:fr")
        precondition(parisItems.first { $0.name == "text" }?.value == "法国巴黎")
        precondition(value("filter") == nil, "no country name, no filter")
    }

    static func checkParsing() {
        let json = #"""
        {"results":[
          {"name":"东京塔","formatted":"东京塔, 芝公园4丁目2-8, 港区, 日本","address_line1":"东京塔",
           "address_line2":"芝公园4丁目2-8, 港区, 日本","lat":35.65858,"lon":139.74543,
           "result_type":"amenity","country_code":"jp"},
          {"formatted":"391 Orchard Road, Singapore","address_line1":"391 Orchard Road",
           "address_line2":"Singapore 238872","lat":1.3025,"lon":103.8345,"result_type":"building",
           "country_code":"sg"},
          {"name":"伦敦","formatted":"伦敦, 英国","lat":51.5073,"lon":-0.1276,"result_type":"city"},
          {"name":"Missing coordinates","result_type":"amenity"},
          {"name":"Out of range","lat":123.0,"lon":0.0},
          {"name":"   ","address_line1":"Named by address","lat":1,"lon":2,"result_type":"something-new"}
        ]}
        """#
        let places = try! OverseasPlaceSearch.places(from: Data(json.utf8))
        precondition(places.count == 4, "invalid entries are dropped")

        precondition(places[0].name == "东京塔")
        precondition(places[0].address == "芝公园4丁目2-8, 港区, 日本")
        precondition(places[0].precision == .place && places[0].countryCode == "JP")
        precondition(places[0].latitude == 35.65858 && places[0].longitude == 139.74543)

        // Without a name the first address line names the result and is not repeated.
        precondition(places[1].name == "391 Orchard Road")
        precondition(places[1].address == "Singapore 238872")
        precondition(places[1].precision == .building)

        // A city result keeps the formatted text that differs from its name.
        precondition(places[2].address == "伦敦, 英国" && places[2].precision == .city)
        precondition(places[2].countryCode == nil)

        // Blank names fall back, and unknown result types stay approximate.
        precondition(places[3].name == "Named by address" && places[3].precision == .unknown)

        precondition((try? OverseasPlaceSearch.places(from: Data(#"{"results":[]}"#.utf8)))?.isEmpty == true)
        do {
            _ = try OverseasPlaceSearch.places(from: Data(#"{"statusCode":401}"#.utf8))
            preconditionFailure("an error body is not a result list")
        } catch {
            precondition(error as? OverseasSearchError == .invalidResponse)
        }
    }

    static func checkPrecision() {
        let exact: [OverseasPlace.Precision] = [.building, .place, .street]
        let approximate: [OverseasPlace.Precision] = [.area, .city, .region, .country, .unknown]
        precondition(exact.allSatisfy { !$0.isApproximate })
        precondition(approximate.allSatisfy(\.isApproximate))
        precondition(OverseasPlace.Precision(geoapifyResultType: "suburb") == .area)
        precondition(OverseasPlace.Precision(geoapifyResultType: "postcode") == .area)
        precondition(OverseasPlace.Precision(geoapifyResultType: "county") == .city)
        precondition(OverseasPlace.Precision(geoapifyResultType: "state") == .region)
        precondition(OverseasPlace.Precision(geoapifyResultType: nil) == .unknown)
    }

    static func checkCountryFilter() {
        func code(_ query: String) -> String? { OverseasPlaceSearch.countryCode(in: query) }
        precondition(code("法国巴黎埃菲尔铁塔") == "fr")
        precondition(code("  日本东京都港区芝公园4丁目2-8") == "jp")
        precondition(code("美國紐約第五大道350號") == "us")
        precondition(code("英国伦敦唐宁街10号") == "gb")
        // The longest name wins: 印度尼西亚 is not 印度.
        precondition(code("印度尼西亚巴厘岛") == "id")
        precondition(code("印度孟买") == "in")
        precondition(code("澳大利亚悉尼歌剧院") == "au" && code("澳门大三巴") == "mo")
        // Only a leading country name counts.
        precondition(code("东京塔") == nil)
        precondition(code("巴黎日本料理") == nil)
        precondition(code("Eiffel Tower, Paris") == nil)
    }

    static func checkStreetAddressLabelling() {
        let addresses = [
            "英国伦敦唐宁街10号", "美國紐約第五大道350號", "日本东京都港区芝公园4丁目2-8",
            "東京都港区芝公園4丁目2-8", "新加坡乌节路391号", "350 Fifth Avenue, New York",
            "London, 10 Downing Street", "銀座1-2-3"
        ]
        let places = ["法国巴黎埃菲尔铁塔", "东京塔", "Marina Bay Sands", "日本东京", "Route 66"]
        for query in addresses {
            precondition(OverseasPlaceSearch.looksLikeStreetAddress(query), "\(query) is an address")
        }
        for query in places {
            precondition(!OverseasPlaceSearch.looksLikeStreetAddress(query), "\(query) is not an address")
        }

        func place(_ precision: OverseasPlace.Precision) -> OverseasPlace {
            OverseasPlace(name: "2-8", address: "小金井市", latitude: 35.7, longitude: 139.5,
                          precision: precision, countryCode: "JP")
        }
        let results = [place(.building), place(.place), place(.street), place(.city)]

        // For a house-number query only a building stays exact.
        let labelled = OverseasPlaceSearch.labelled(results, for: "东京都港区芝公园4丁目2-8")
        precondition(labelled.map(\.precision) == [.building, .unknown, .unknown, .unknown])
        precondition(labelled.map(\.name) == results.map(\.name), "only the label changes")

        // Other queries keep their labels.
        precondition(OverseasPlaceSearch.labelled(results, for: "东京塔") == results)
    }

    static func checkQuota() {
        var quota = OverseasSearchQuota()
        for _ in 0..<OverseasSearchQuota.dailyLimit {
            precondition(quota.canSearch(on: "2026-10-28"))
            quota.recordSearch(on: "2026-10-28")
        }
        precondition(!quota.canSearch(on: "2026-10-28"), "the daily limit stops further searches")
        precondition(quota.canSearch(on: "2026-10-29"), "a new day starts a new count")
        quota.recordSearch(on: "2026-10-29")
        precondition(quota.count == 1)

        // Saved quotas round-trip through JSON.
        let saved = try! JSONEncoder().encode(quota)
        precondition(try! JSONDecoder().decode(OverseasSearchQuota.self, from: saved) == quota)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let date = ISO8601DateFormatter().date(from: "2026-10-28T16:30:00Z")!
        precondition(OverseasSearchQuota.dayKey(for: date, calendar: calendar) == "2026-10-29")
    }

    static func checkCache() {
        let place = OverseasPlace(name: "Tokyo Tower", address: "Minato", latitude: 35.6586,
                                  longitude: 139.7454, precision: .place, countryCode: "JP")
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var cache = OverseasSearchCache()
        cache.store([place], for: "  Tokyo   Tower ", at: start)

        // Spacing and case do not create separate entries.
        precondition(cache.places(for: "tokyo tower", at: start.addingTimeInterval(60)) == [place])
        precondition(cache.places(for: "Tokyo Tower", at: start.addingTimeInterval(OverseasSearchCache.lifetime - 1)) == [place])
        precondition(cache.places(for: "Tokyo Tower", at: start.addingTimeInterval(OverseasSearchCache.lifetime)) == nil)
        precondition(cache.places(for: "Eiffel Tower", at: start) == nil)

        // An empty answer is cached too, so repeating it costs nothing.
        cache.store([], for: "nowhere", at: start)
        precondition(cache.places(for: "nowhere", at: start) == [])

        // The oldest entries are dropped beyond capacity.
        var full = OverseasSearchCache()
        for index in 0...OverseasSearchCache.capacity {
            full.store([place], for: "query \(index)", at: start.addingTimeInterval(Double(index)))
        }
        let latest = start.addingTimeInterval(Double(OverseasSearchCache.capacity))
        precondition(full.places(for: "query 0", at: latest) == nil)
        precondition(full.places(for: "query 1", at: latest) == [place])
        precondition(full.places(for: "query \(OverseasSearchCache.capacity)", at: latest) == [place])

        let saved = try! JSONEncoder().encode(full)
        precondition(try! JSONDecoder().decode(OverseasSearchCache.self, from: saved) == full)

        // Keys carry the cache version, so entries from older labelling are ignored.
        precondition(OverseasSearchCache.key(for: " Tokyo  Tower") == "\(OverseasSearchCache.version)|tokyo tower")
    }
}
