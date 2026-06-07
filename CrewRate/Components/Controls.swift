import PhotosUI
import LinkPresentation
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
        }
        .buttonStyle(CrewPrimaryButtonStyle())
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

final class AppShareItem: NSObject, UIActivityItemSource {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        url
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = "Construction Gossip"
        metadata.originalURL = url
        metadata.url = url
        if let icon = UIImage(named: "BrandLogo") {
            metadata.iconProvider = NSItemProvider(object: icon)
        }
        return metadata
    }
}

@MainActor
private final class RemoteImageLoader: ObservableObject {
    enum State {
        case loading
        case loaded(UIImage)
        case failed
    }

    @Published private(set) var state: State = .loading
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func load() async {
        guard case .loading = state else { return }
        for attempt in 0..<2 {
            do {
                var request = URLRequest(url: url)
                request.cachePolicy = attempt == 0 ? .returnCacheDataElseLoad : .reloadIgnoringLocalCacheData
                request.timeoutInterval = 30
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      200..<300 ~= httpResponse.statusCode,
                      let image = UIImage(data: data) else {
                    throw URLError(.cannotDecodeContentData)
                }
                state = .loaded(image)
                return
            } catch {
                if attempt == 0 {
                    try? await Task.sleep(for: .milliseconds(350))
                }
            }
        }
        state = .failed
    }
}

struct RemoteImage<Content: View, Placeholder: View, Failure: View>: View {
    @StateObject private var loader: RemoteImageLoader
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    private let failure: () -> Failure

    init(
        url: URL,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        _loader = StateObject(wrappedValue: RemoteImageLoader(url: url))
        self.content = content
        self.placeholder = placeholder
        self.failure = failure
    }

    var body: some View {
        Group {
            switch loader.state {
            case .loading:
                placeholder()
            case .loaded(let image):
                content(Image(uiImage: image))
            case .failed:
                failure()
            }
        }
        .task { await loader.load() }
    }
}

struct TextInputField: View {
    let title: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        TextField(title, text: $text, axis: axis)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, CrewDesign.Spacing.md)
            .frame(minHeight: CrewDesign.Size.controlHeight)
            .background(Color.crewGray)
            .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous)
                    .stroke(Color.crewDivider, lineWidth: 0.75)
            }
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
            } else if !anonymous, let url = profile?.profilePhotoURL {
                RemoteImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView()
                } failure: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: size * 0.5))
                        .foregroundStyle(Color.crewOrange)
                }
                .clipShape(Circle())
            } else {
                Image(systemName: anonymous ? "person.fill.questionmark" : "person.crop.circle.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(anonymous ? .white : Color.crewOrange)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            Circle()
                .stroke(Color.crewSurface, lineWidth: size >= 70 ? 3 : 2)
                .shadow(color: .black.opacity(0.12), radius: 1)
        }
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
                        .buttonStyle(CrewSecondaryButtonStyle())
                        .fixedSize()
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
            Text(title)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        withAnimation(CrewDesign.standardAnimation) {
                            value = rating
                        }
                    } label: {
                        Image(systemName: rating <= value ? "star.fill" : "star")
                            .foregroundStyle(Color.crewOrange)
                            .font(.system(size: 21, weight: .medium))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(CrewPressButtonStyle())
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
        .buttonStyle(CrewSecondaryButtonStyle())
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
            .font(.subheadline)
            .foregroundStyle(Color.red)
            .padding(CrewDesign.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
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
                .padding(.horizontal, CrewDesign.Spacing.md)
                .frame(height: CrewDesign.Size.compactControlHeight)
                .background(isSelected ? Color.crewNavy : Color.crewGray)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.small, style: .continuous))
        }
        .buttonStyle(CrewPressButtonStyle())
    }
}

struct BadgeView: View {
    let text: String
    var systemImage: String?

    var body: some View {
        Label(text, systemImage: systemImage ?? "tag")
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.crewGray)
            .foregroundStyle(Color.crewInk)
            .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.small, style: .continuous))
    }
}

struct CrewSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: CrewDesign.Spacing.xxs) {
            Text(title)
                .font(.title3.weight(.bold))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CrewActionButton: View {
    let title: String
    let systemImage: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(prominent ? AnyCrewButtonStyle.primary : AnyCrewButtonStyle.secondary)
    }
}

private struct AnyCrewButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    static let primary = AnyCrewButtonStyle(kind: .primary)
    static let secondary = AnyCrewButtonStyle(kind: .secondary)
    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        Group {
            switch kind {
            case .primary:
                configuration.label
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: CrewDesign.Size.compactControlHeight)
                    .padding(.horizontal, CrewDesign.Spacing.sm)
                    .foregroundStyle(.white)
                    .background(Color.crewNavy.opacity(configuration.isPressed ? 0.78 : 1))
            case .secondary:
                configuration.label
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: CrewDesign.Size.compactControlHeight)
                    .padding(.horizontal, CrewDesign.Spacing.sm)
                    .foregroundStyle(.primary)
                    .background(Color.crewGray.opacity(configuration.isPressed ? 0.65 : 1))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.small, style: .continuous))
        .scaleEffect(configuration.isPressed ? 0.98 : 1)
        .animation(CrewDesign.standardAnimation, value: configuration.isPressed)
    }
}
