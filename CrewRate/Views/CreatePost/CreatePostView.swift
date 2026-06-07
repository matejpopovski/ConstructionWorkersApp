import PhotosUI
import SwiftUI
import UIKit

struct CreatePostView: View {
    @EnvironmentObject private var session: SessionViewModel
    @State private var text = ""
    @State private var isAnonymous = false
    @State private var company = ""
    @State private var city: String?
    @State private var state: String?
    @State private var trade: TradePosition = .generalLaborer
    @State private var customTrade = ""
    @State private var payType: PayType = .hourly
    @State private var payAmount = ""
    @State private var benefits = ""
    @State private var safetyRating = 3
    @State private var treatmentRating = 3
    @State private var supervisorRating = 3
    @State private var workloadRating = 3
    @State private var payFairnessRating = 3
    @State private var overtimeAvailable = false
    @State private var wouldRecommend = true
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var photoErrorMessage: String?
    @State private var validationMessage: String?
    @State private var showingPosted = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What should other workers know about this job or employer?", text: $text, axis: .vertical)
                        .lineLimit(4...8)
                    ImagePicker(selectedItem: $selectedPhoto)
                    if let selectedPhotoData, let image = UIImage(data: selectedPhotoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    selectedPhoto = nil
                                    self.selectedPhotoData = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color.crewNavy.opacity(0.75))
                                }
                                .padding(8)
                            }
                    }
                    if let photoErrorMessage {
                        ErrorView(message: photoErrorMessage)
                    }
                    if let validationMessage {
                        ErrorView(message: validationMessage)
                    }
                    Toggle("Post anonymously", isOn: $isAnonymous)
                }
                Section("Company and Job") {
                    TextField("Company or employer", text: $company)
                    Picker("Job / Position", selection: $trade) {
                        ForEach(TradePosition.allCases) { trade in
                            Text(trade.rawValue).tag(trade)
                        }
                    }
                    if trade == .other {
                        TextField("Write job or position", text: $customTrade)
                    }
                    StateCityPicker(state: $state, city: $city)
                    Toggle("Would recommend this employer", isOn: $wouldRecommend)
                }
                Section("Pay and Conditions") {
                    Picker("Pay type", selection: $payType) {
                        ForEach(PayType.allCases) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    TextField("Pay amount before deductions", text: $payAmount)
                        .keyboardType(.decimalPad)
                    Toggle("Overtime available", isOn: $overtimeAvailable)
                    TextField("Benefits received, per diem, travel pay", text: $benefits)
                }
                Section("Ratings") {
                    RatingPicker(title: "Safety", value: $safetyRating)
                    RatingPicker(title: "Treatment", value: $treatmentRating)
                    RatingPicker(title: "Supervisor flexibility", value: $supervisorRating)
                    RatingPicker(title: "Workload", value: $workloadRating)
                    RatingPicker(title: "Pay fairness", value: $payFairnessRating)
                }
                Section {
                    Text(CrewRateConstants.warningCopy)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    PrimaryButton("Post Review", systemImage: "paperplane.fill", action: createPost)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
            }
            .navigationTitle("Create Review")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.crewCanvas)
            .onChange(of: selectedPhoto) { _, newItem in
                Task { await loadSelectedPhoto(newItem) }
            }
            .overlay {
                if showingPosted {
                    Label("Posted", systemImage: "checkmark.circle.fill")
                        .font(.title2.bold())
                        .padding(.horizontal, 22)
                        .padding(.vertical, 16)
                        .background(Color.crewOrange)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
                        .shadow(radius: 12)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    private func createPost() {
        guard let profile = session.currentProfile ?? session.profileService.profiles.first else { return }
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCompany = company.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCustomTrade = customTrade.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCompany.isEmpty else {
            validationMessage = "Company or employer is required."
            return
        }
        guard !trimmedText.isEmpty else {
            validationMessage = "Add details about what happened on the job."
            return
        }
        guard state != nil, city?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            validationMessage = "Choose a state and enter the job city."
            return
        }
        guard trade != .other || !trimmedCustomTrade.isEmpty else {
            validationMessage = "Write the custom job or position."
            return
        }
        guard let amount = Decimal(string: payAmount), amount > 0 else {
            validationMessage = "Enter a valid pay amount."
            return
        }
        validationMessage = nil
        let attachedImages = selectedPhotoData.map { [$0] } ?? []
        let tradeLabel = trade == .other && !trimmedCustomTrade.isEmpty ? trimmedCustomTrade : trade.rawValue
        let post = Post(id: UUID(), userID: profile.id, authorUsername: profile.username, postType: .workReport, textContent: trimmedText, imageURLs: [], imageData: attachedImages, isAnonymous: isAnonymous, companyOrEmployer: trimmedCompany, tradePosition: trade, customTradePosition: trade == .other ? trimmedCustomTrade : nil, city: city, state: state, payType: payType, payAmount: amount, overtimeAvailable: overtimeAvailable, benefits: benefits.csvValues, supervisorFlexibilityRating: supervisorRating, treatmentRating: treatmentRating, safetyRating: safetyRating, workloadRating: workloadRating, payFairnessRating: payFairnessRating, wouldRecommend: wouldRecommend, tags: [tradeLabel, city, state, trimmedCompany, overtimeAvailable ? "Overtime" : nil, wouldRecommend ? "Recommended" : "Not recommended"].compactMap { $0 }.filter { !$0.isEmpty }, likeCount: 0, commentCount: 0, createdAt: .now, updatedAt: .now)
        session.postService.create(post)
        text = ""
        isAnonymous = false
        company = ""
        city = nil
        state = nil
        trade = .generalLaborer
        payAmount = ""
        benefits = ""
        customTrade = ""
        payType = .hourly
        safetyRating = 3
        treatmentRating = 3
        supervisorRating = 3
        workloadRating = 3
        payFairnessRating = 3
        overtimeAvailable = false
        wouldRecommend = true
        selectedPhoto = nil
        selectedPhotoData = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showingPosted = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.2)) {
                showingPosted = false
            }
        }
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
        photoErrorMessage = nil
        selectedPhotoData = nil
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let optimizedData = ImageOptimizer.optimizedJPEGData(from: data, preset: .post) else {
                photoErrorMessage = "That photo could not be loaded."
                return
            }
            selectedPhotoData = optimizedData
        } catch {
            photoErrorMessage = "Photo attach failed. Please try another image."
        }
    }
}

extension String {
    var csvValues: [String] {
        split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
