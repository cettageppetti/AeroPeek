import AppKit
import UniformTypeIdentifiers

@MainActor
enum AppIconProvider {
    private static var cache: [String: NSImage] = [:]

    static func icon(for applicationName: String) -> NSImage {
        if let cached = cache[applicationName] { return cached }

        let icon = NSWorkspace.shared.runningApplications
            .first { $0.localizedName?.caseInsensitiveCompare(applicationName) == .orderedSame }?
            .icon
            ?? iconFromStandardLocations(applicationName)
            ?? NSWorkspace.shared.icon(for: UTType.application)

        icon.size = NSSize(width: 20, height: 20)
        cache[applicationName] = icon
        return icon
    }

    private static func iconFromStandardLocations(_ applicationName: String) -> NSImage? {
        let roots = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]
        let fileManager = FileManager.default
        for root in roots {
            let path = URL(fileURLWithPath: root).appendingPathComponent("\(applicationName).app").path
            if fileManager.fileExists(atPath: path) { return NSWorkspace.shared.icon(forFile: path) }
        }
        return nil
    }
}
