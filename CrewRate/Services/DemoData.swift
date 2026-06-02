import Foundation

enum DemoData {
    static let currentUserID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!

    static var currentUser = Profile(
        id: currentUserID,
        username: "matej",
        email: "matej@example.com",
        firstName: nil,
        lastName: nil,
        profilePhotoURL: nil,
        profilePhotoData: nil,
        state: "IL",
        city: "Chicago",
        streetAddressPrivateOnly: nil,
        tradePosition: .carpenter,
        experienceLevel: "Journeyman",
        currentCompanyOrEmployer: nil,
        payType: nil,
        payAmount: nil,
        unionStatus: .preferNotToSay,
        yearsExperience: 6,
        certifications: ["OSHA 30"],
        benefitsReceived: [],
        languagesSpoken: ["English"],
        bio: "Building CrewRate.",
        openToWork: false,
        willingToRelocate: false,
        showRealName: false,
        showCurrentCompany: false,
        showPayOnProfile: false,
        showCityState: true,
        allowFriendRequests: true,
        allowMessagesFrom: .friends
    )

    static let profiles: [Profile] = [
        currentUser,
        makeProfile("sparky_mia", trade: .electrician, city: "Austin", state: "TX", open: true),
        makeProfile("concrete_ray", trade: .concreteFinisher, city: "Phoenix", state: "AZ", open: false),
        makeProfile("operator_jules", trade: .heavyEquipmentOperator, city: "Columbus", state: "OH", open: true),
        makeProfile("roofline_nate", trade: .roofer, city: "Tampa", state: "FL", open: false)
    ]

    static var posts: [Post] = [
        makePost(author: profiles[1], type: .workReport, text: "New commercial rough-in wrapped today. Good crew, overtime was available, safety meetings were actually useful.", company: "Lone Star Electric", trade: .electrician, city: "Austin", state: "TX", payType: .hourly, payAmount: 36, ratings: 4),
        makePost(author: profiles[2], type: .general, text: "Anyone else switching to early pours this week because of the heat?", company: nil, trade: .concreteFinisher, city: "Phoenix", state: "AZ", payType: nil, payAmount: nil, ratings: nil),
        makePost(author: profiles[3], type: .workReport, text: "Decent site, equipment is maintained, foreman listens when something is unsafe.", company: "Buckeye Civil", trade: .heavyEquipmentOperator, city: "Columbus", state: "OH", payType: .hourly, payAmount: 42, ratings: 5),
        makePost(author: profiles[4], type: .general, text: "Looking for recommendations on breathable summer gear that still holds up on roofing jobs.", company: nil, trade: .roofer, city: "Tampa", state: "FL", payType: nil, payAmount: nil, ratings: nil)
    ]

    static var comments: [Comment] = [
        Comment(id: UUID(), postID: posts[0].id, userID: profiles[0].id, parentCommentID: nil, authorUsername: "matej", textContent: "That safety part is good to hear.", imageURLs: [], likeCount: 2, createdAt: .now.addingTimeInterval(-2400), updatedAt: .now.addingTimeInterval(-2400)),
        Comment(id: UUID(), postID: posts[0].id, userID: profiles[1].id, parentCommentID: nil, authorUsername: "sparky_mia", textContent: "Yeah, made a big difference on the schedule.", imageURLs: [], likeCount: 1, createdAt: .now.addingTimeInterval(-1800), updatedAt: .now.addingTimeInterval(-1800))
    ]

    static func makeProfile(_ username: String, trade: TradePosition, city: String, state: String, open: Bool) -> Profile {
        Profile(id: UUID(), username: username, email: nil, firstName: nil, lastName: nil, profilePhotoURL: nil, profilePhotoData: nil, state: state, city: city, streetAddressPrivateOnly: nil, tradePosition: trade, experienceLevel: nil, currentCompanyOrEmployer: nil, payType: nil, payAmount: nil, unionStatus: nil, yearsExperience: Int.random(in: 2...18), certifications: [], benefitsReceived: [], languagesSpoken: ["English"], bio: nil, openToWork: open, willingToRelocate: false, showRealName: false, showCurrentCompany: false, showPayOnProfile: false, showCityState: true, allowFriendRequests: true, allowMessagesFrom: .friends)
    }

    static func makePost(author: Profile, type: PostType, text: String, company: String?, trade: TradePosition?, city: String?, state: String?, payType: PayType?, payAmount: Decimal?, ratings: Int?) -> Post {
        Post(id: UUID(), userID: author.id, authorUsername: author.username, postType: type, textContent: text, imageURLs: [], imageData: [], isAnonymous: false, companyOrEmployer: company, tradePosition: trade, city: city, state: state, payType: payType, payAmount: payAmount, overtimeAvailable: type == .workReport ? true : nil, benefits: type == .workReport ? ["Health insurance", "PTO"] : [], supervisorFlexibilityRating: ratings, treatmentRating: ratings, safetyRating: ratings, workloadRating: ratings, payFairnessRating: ratings, wouldRecommend: ratings.map { $0 >= 4 }, tags: trade.map { [$0.rawValue] } ?? [], likeCount: Int.random(in: 2...38), commentCount: Int.random(in: 0...9), createdAt: .now.addingTimeInterval(Double.random(in: -200000 ... -1000)), updatedAt: .now)
    }
}
