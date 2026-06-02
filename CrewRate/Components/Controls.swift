import PhotosUI
import SwiftUI
import UIKit

struct PrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage ?? "checkmark")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.crewOrange)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct TextInputField: View {
    let title: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        TextField(title, text: $text, axis: axis)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ProfileImageView: View {
    let profile: Profile?
    var size: CGFloat = 44
    var anonymous = false

    var body: some View {
        ZStack {
            Circle().fill(anonymous ? Color.crewNavy : Color.crewOrange.opacity(0.16))
            if !anonymous, let data = profile?.profilePhotoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Image(systemName: anonymous ? "person.fill.questionmark" : "person.crop.circle.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(anonymous ? .white : Color.crewOrange)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(anonymous ? "Anonymous worker" : profile?.username ?? "Profile photo")
    }
}

struct StateCityPicker: View {
    @Binding var state: String?
    @Binding var city: String?
    @State private var cityText: String

    init(state: Binding<String?>, city: Binding<String?>) {
        _state = state
        _city = city
        _cityText = State(initialValue: city.wrappedValue ?? "")
    }

    var body: some View {
        Picker("State", selection: stateSelection) {
            Text("Choose state").tag("")
            ForEach(LocationData.states, id: \.self) { state in
                Text(state).tag(state)
            }
        }
        .onChange(of: state) { _, newState in
            guard newState != nil else {
                city = nil
                cityText = ""
                return
            }
            city = nil
            cityText = ""
        }

        TextField("City", text: $cityText)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .disabled(state == nil || state == "")
            .onAppear { cityText = city ?? "" }
            .onChange(of: cityText) { _, newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                city = trimmed.isEmpty ? nil : trimmed
            }

        let suggestions = LocationData.suggestedCities(for: state, matching: cityText)
        if !suggestions.isEmpty && suggestions.first?.caseInsensitiveCompare(cityText) != .orderedSame {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            cityText = suggestion
                            city = suggestion
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var stateSelection: Binding<String> {
        Binding(
            get: { state ?? "" },
            set: { state = $0.isEmpty ? nil : $0 }
        )
    }
}

struct RatingPicker: View {
    let title: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold))
            HStack {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        value = rating
                    } label: {
                        Image(systemName: rating <= value ? "star.fill" : "star")
                            .foregroundStyle(Color.crewOrange)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct TagPicker: View {
    @Binding var tagsText: String

    var body: some View {
        TextInputField(title: "Tags, separated by commas", text: $tagsText)
    }
}

struct ImagePicker: View {
    @Binding var selectedItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Label("Add Photo", systemImage: "photo.on.rectangle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage)
    }
}

struct LoadingView: View {
    var body: some View {
        ProgressView("Loading")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct FilterChip: View {
    let title: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.crewOrange : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct BadgeView: View {
    let text: String
    var systemImage: String?

    var body: some View {
        Label(text, systemImage: systemImage ?? "tag")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.crewGray)
            .foregroundStyle(Color.crewInk)
            .clipShape(Capsule())
    }
}
