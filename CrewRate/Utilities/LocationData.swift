import Foundation

enum LocationData {
    static let states = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"
    ]

    static let citiesByState: [String: [String]] = loadCities()

    static func cities(for state: String?) -> [String] {
        guard let state, let cities = citiesByState[state] else { return [] }
        return cities
    }

    static func suggestedCities(for state: String?, matching query: String, limit: Int = 8) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lowercased = trimmed.lowercased()
        return cities(for: state)
            .filter { $0.lowercased().contains(lowercased) }
            .prefix(limit)
            .map { $0 }
    }

    private static func loadCities() -> [String: [String]] {
        guard let url = Bundle.main.url(forResource: "USCitiesByState", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return fallbackCitiesByState
        }
        return decoded
    }

    private static let fallbackCitiesByState: [String: [String]] = [
        "CA": ["Los Angeles", "San Diego", "San Jose", "Sacramento", "Fresno"],
        "FL": ["Jacksonville", "Miami", "Tampa", "Orlando", "St. Petersburg"],
        "IL": ["Chicago", "Aurora", "Naperville", "Rockford"],
        "NY": ["New York", "Buffalo", "Rochester", "Albany"],
        "OH": ["Columbus", "Cleveland", "Cincinnati"],
        "PA": ["Philadelphia", "Pittsburgh", "Allentown"],
        "TX": ["Houston", "San Antonio", "Dallas", "Austin", "Fort Worth"]
    ]
}

struct StateCitySelection: Equatable {
    var state: String?
    var city: String?
}
