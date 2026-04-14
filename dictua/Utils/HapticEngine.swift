import UIKit

public enum HapticEngine {
    public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let g = UIImpactFeedbackGenerator(style: style)
        g.impactOccurred()
    }

    public static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(type)
    }

    public static func success() {
        notification(.success)
    }

    public static func error() {
        notification(.error)
    }

    public static func warning() {
        notification(.warning)
    }
}
