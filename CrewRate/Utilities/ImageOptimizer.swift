import UIKit

enum ImageOptimizer {
    enum Preset {
        case profile
        case post
        case message

        var maxDimension: CGFloat {
            switch self {
            case .profile:
                512
            case .post:
                1024
            case .message:
                1024
            }
        }

        var quality: CGFloat {
            switch self {
            case .profile:
                0.72
            case .post:
                0.68
            case .message:
                0.74
            }
        }
    }

    static func optimizedJPEGData(from data: Data, preset: Preset) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let normalized = image.normalizedOrientation()
        let resized = normalized.resizedToFit(maxDimension: preset.maxDimension)
        return resized.jpegData(compressionQuality: preset.quality)
    }
}

private extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        return UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func resizedToFit(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }
        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
