import Foundation

enum LocationData {
    static let states = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"
    ]

    static let citiesByState: [String: [String]] = [
        "AL": ["Birmingham", "Huntsville", "Mobile", "Montgomery"],
        "AK": ["Anchorage", "Fairbanks", "Juneau"],
        "AZ": ["Phoenix", "Tucson", "Mesa", "Scottsdale"],
        "AR": ["Little Rock", "Fayetteville", "Fort Smith"],
        "CA": ["Los Angeles", "San Diego", "San Jose", "Sacramento", "Fresno"],
        "CO": ["Denver", "Colorado Springs", "Aurora", "Fort Collins"],
        "CT": ["Bridgeport", "New Haven", "Hartford", "Stamford"],
        "DE": ["Wilmington", "Dover", "Newark"],
        "FL": ["Jacksonville", "Miami", "Tampa", "Orlando", "St. Petersburg"],
        "GA": ["Atlanta", "Savannah", "Augusta", "Columbus"],
        "HI": ["Honolulu", "Hilo", "Kailua"],
        "ID": ["Boise", "Meridian", "Nampa"],
        "IL": ["Chicago", "Aurora", "Naperville", "Rockford"],
        "IN": ["Indianapolis", "Fort Wayne", "Evansville"],
        "IA": ["Des Moines", "Cedar Rapids", "Davenport"],
        "KS": ["Wichita", "Overland Park", "Kansas City"],
        "KY": ["Louisville", "Lexington", "Bowling Green"],
        "LA": ["New Orleans", "Baton Rouge", "Shreveport"],
        "ME": ["Portland", "Lewiston", "Bangor"],
        "MD": ["Baltimore", "Frederick", "Rockville"],
        "MA": ["Boston", "Worcester", "Springfield"],
        "MI": ["Detroit", "Grand Rapids", "Lansing"],
        "MN": ["Minneapolis", "St. Paul", "Rochester"],
        "MS": ["Jackson", "Gulfport", "Southaven"],
        "MO": ["Kansas City", "St. Louis", "Springfield"],
        "MT": ["Billings", "Missoula", "Bozeman"],
        "NE": ["Omaha", "Lincoln", "Bellevue"],
        "NV": ["Las Vegas", "Henderson", "Reno"],
        "NH": ["Manchester", "Nashua", "Concord"],
        "NJ": ["Newark", "Jersey City", "Paterson"],
        "NM": ["Albuquerque", "Santa Fe", "Las Cruces"],
        "NY": ["New York", "Buffalo", "Rochester", "Albany"],
        "NC": ["Charlotte", "Raleigh", "Greensboro"],
        "ND": ["Fargo", "Bismarck", "Grand Forks"],
        "OH": ["Columbus", "Cleveland", "Cincinnati"],
        "OK": ["Oklahoma City", "Tulsa", "Norman"],
        "OR": ["Portland", "Eugene", "Salem"],
        "PA": ["Philadelphia", "Pittsburgh", "Allentown"],
        "RI": ["Providence", "Warwick", "Cranston"],
        "SC": ["Charleston", "Columbia", "Greenville"],
        "SD": ["Sioux Falls", "Rapid City", "Aberdeen"],
        "TN": ["Nashville", "Memphis", "Knoxville"],
        "TX": ["Houston", "San Antonio", "Dallas", "Austin", "Fort Worth"],
        "UT": ["Salt Lake City", "Provo", "Ogden"],
        "VT": ["Burlington", "South Burlington", "Rutland"],
        "VA": ["Virginia Beach", "Richmond", "Norfolk"],
        "WA": ["Seattle", "Spokane", "Tacoma"],
        "WV": ["Charleston", "Huntington", "Morgantown"],
        "WI": ["Milwaukee", "Madison", "Green Bay"],
        "WY": ["Cheyenne", "Casper", "Laramie"]
    ]

    static func cities(for state: String?) -> [String] {
        guard let state, let cities = citiesByState[state] else { return [] }
        return cities
    }
}

struct StateCitySelection: Equatable {
    var state: String?
    var city: String?
}
