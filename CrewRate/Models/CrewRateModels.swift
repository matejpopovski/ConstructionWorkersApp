import Foundation

enum TradePosition: String, CaseIterable, Codable, Identifiable {
    case generalLaborer = "General Laborer"
    case constructionHelper = "Construction Helper"
    case apprentice = "Apprentice"
    case carpenter = "Carpenter"
    case electrician = "Electrician"
    case plumber = "Plumber"
    case pipefitter = "Pipefitter"
    case steamfitter = "Steamfitter"
    case hvacTechnician = "HVAC Technician"
    case roofer = "Roofer"
    case painter = "Painter"
    case drywallInstaller = "Drywall Installer"
    case taper = "Taper"
    case mason = "Mason"
    case bricklayer = "Bricklayer"
    case concreteFinisher = "Concrete Finisher"
    case cementMason = "Cement Mason"
    case tileSetter = "Tile Setter"
    case flooringInstaller = "Flooring Installer"
    case glazier = "Glazier"
    case welder = "Welder"
    case ironworker = "Ironworker"
    case rebarWorker = "Rebar Worker"
    case sheetMetalWorker = "Sheet Metal Worker"
    case insulationWorker = "Insulation Worker"
    case heavyEquipmentOperator = "Heavy Equipment Operator"
    case craneOperator = "Crane Operator"
    case excavatorOperator = "Excavator Operator"
    case pavingOperator = "Paving Operator"
    case truckDriver = "Truck Driver"
    case fenceInstaller = "Fence Installer"
    case solarInstaller = "Solar Installer"
    case elevatorInstaller = "Elevator/Escalator Installer"
    case buildingInspector = "Building Inspector"
    case siteSupervisor = "Site Supervisor"
    case foreman = "Foreman"
    case projectManager = "Project Manager"
    case safetyManager = "Safety Manager"
    case estimator = "Estimator"
    case other = "Other"

    var id: String { rawValue }
}

enum PayType: String, CaseIterable, Codable, Identifiable {
    case hourly = "hourly"
    case salary = "salary"
    case pieceRate = "piece-rate"
    case contract = "contract"

    var id: String { rawValue }
}

enum UnionStatus: String, CaseIterable, Codable, Identifiable {
    case union = "union"
    case nonUnion = "non-union"
    case preferNotToSay = "prefer not to say"

    var id: String { rawValue }
}

enum AllowMessagesFrom: String, CaseIterable, Codable, Identifiable {
    case everyone
    case friends
    case noOne = "no_one"

    var id: String { rawValue }
}

enum PostType: String, Codable, CaseIterable, Identifiable {
    case general
    case workReport = "work_report"

    var id: String { rawValue }
}

enum FriendRequestStatus: String, Codable {
    case pending
    case accepted
    case rejected
}

struct Profile: Identifiable, Codable, Equatable {
    var id: UUID
    var username: String
    var email: String?
    var firstName: String?
    var lastName: String?
    var profilePhotoURL: URL?
    var profilePhotoData: Data? = nil
    var state: String?
    var city: String?
    var streetAddressPrivateOnly: String?
    var tradePosition: TradePosition?
    var customTradePosition: String? = nil
    var experienceLevel: String?
    var currentCompanyOrEmployer: String?
    var payType: PayType?
    var payAmount: Decimal?
    var unionStatus: UnionStatus?
    var yearsExperience: Int?
    var certifications: [String]
    var benefitsReceived: [String]
    var languagesSpoken: [String]
    var bio: String?
    var openToWork: Bool
    var willingToRelocate: Bool
    var showRealName: Bool
    var showCurrentCompany: Bool
    var showPayOnProfile: Bool
    var showCityState: Bool
    var allowFriendRequests: Bool
    var allowMessagesFrom: AllowMessagesFrom

    var tradeLabel: String? {
        if let customTradePosition, !customTradePosition.isEmpty {
            return customTradePosition
        }
        return tradePosition?.rawValue
    }

    var displayName: String {
        if showRealName, let firstName, !firstName.isEmpty {
            return [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        }
        return username
    }
}

struct Post: Identifiable, Codable, Equatable {
    var id: UUID
    var userID: UUID
    var authorUsername: String
    var postType: PostType
    var textContent: String?
    var imageURLs: [URL]
    var imageData: [Data]
    var isAnonymous: Bool
    var companyOrEmployer: String?
    var tradePosition: TradePosition?
    var customTradePosition: String? = nil
    var city: String?
    var state: String?
    var payType: PayType?
    var payAmount: Decimal?
    var overtimeAvailable: Bool?
    var benefits: [String]
    var supervisorFlexibilityRating: Int?
    var treatmentRating: Int?
    var safetyRating: Int?
    var workloadRating: Int?
    var payFairnessRating: Int?
    var wouldRecommend: Bool?
    var tags: [String]
    var likeCount: Int
    var commentCount: Int
    var createdAt: Date
    var updatedAt: Date

    var tradeLabel: String? {
        if let customTradePosition, !customTradePosition.isEmpty {
            return customTradePosition
        }
        return tradePosition?.rawValue
    }
}

struct Comment: Identifiable, Codable, Equatable {
    var id: UUID
    var postID: UUID
    var userID: UUID
    var parentCommentID: UUID?
    var authorUsername: String
    var textContent: String?
    var imageURLs: [URL]
    var imageData: [Data] = []
    var likeCount: Int
    var createdAt: Date
    var updatedAt: Date
}

struct FriendRequest: Identifiable, Codable, Equatable {
    var id: UUID
    var senderID: UUID
    var receiverID: UUID
    var senderUsername: String
    var status: FriendRequestStatus
    var createdAt: Date
}

struct Report: Identifiable, Codable {
    var id: UUID
    var reporterID: UUID
    var targetType: String
    var targetID: UUID
    var reason: String
    var createdAt: Date
}

struct Conversation: Identifiable, Codable {
    var id: UUID
    var title: String?
    var createdAt: Date
}

struct Message: Identifiable, Codable {
    var id: UUID
    var conversationID: UUID
    var senderID: UUID
    var body: String
    var imageData: Data? = nil
    var createdAt: Date
}

struct ChatMessage: Identifiable, Codable, Equatable {
    var id: UUID
    var senderID: UUID
    var receiverID: UUID
    var body: String
    var imageData: Data?
    var imageURLs: [URL] = []
    var sharedPostID: UUID?
    var createdAt: Date
}
