import Foundation

/// Dates written into file names, folder paths and EXIF must not follow the
/// user's calendar or locale (e.g. Buddhist or Japanese years), or Photos and
/// other tools will misread them.
nonisolated enum ExportDateFormat {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter
    }

    /// `yyyy-MM-dd_HHmmss`, used in exported file names.
    static func fileNameFormatter() -> DateFormatter {
        formatter("yyyy-MM-dd_HHmmss")
    }

    /// `yyyy:MM:dd HH:mm:ss`, the EXIF date format.
    static func exifFormatter() -> DateFormatter {
        formatter("yyyy:MM:dd HH:mm:ss")
    }

    /// EXIF offset of the local time zone at `date`, e.g. `+02:00`.
    static func exifOffset(for date: Date, in timeZone: TimeZone = .current) -> String {
        let seconds = timeZone.secondsFromGMT(for: date)
        let sign = seconds < 0 ? "-" : "+"
        let minutes = abs(seconds) / 60
        return String(format: "%@%02d:%02d", sign, minutes / 60, minutes % 60)
    }
}
