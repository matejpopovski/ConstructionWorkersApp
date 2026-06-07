import Foundation

enum DateDisplay {
    static func label(for date: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day,
           days >= 2,
           days < 7 {
            return "\(days) days ago"
        }
        if let days = calendar.dateComponents([.day], from: date, to: now).day,
           days >= 7,
           days < 14 {
            return "Last week"
        }
        if let hours = calendar.dateComponents([.hour], from: date, to: now).hour,
           hours < 24 {
            if hours <= 0 {
                let minutes = max(0, calendar.dateComponents([.minute], from: date, to: now).minute ?? 0)
                return minutes < 1 ? "Just now" : "\(minutes)m ago"
            }
            return "\(hours)h ago"
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
