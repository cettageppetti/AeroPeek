import Foundation

struct WorkspaceApplication: Identifiable, Equatable, Sendable {
    var id: String { name }
    let name: String
    let windowCount: Int
}

struct Workspace: Identifiable {
    let id: String
    let applications: [WorkspaceApplication]
    let isActive: Bool

    var windowCount: Int { applications.reduce(0) { $0 + $1.windowCount } }
    var isEmpty: Bool { windowCount == 0 }
}

@MainActor
final class WorkspaceModel: ObservableObject {
    static let workspaceIDs = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "C", "N"]
    @Published private(set) var workspaces: [Workspace] = []
    @Published var selection: String?
    @Published private(set) var errorMessage: String?

    func refresh() {
        Task {
            do {
                let snapshot = try await AeroSpaceClient.snapshot()
                workspaces = Self.workspaceIDs.map {
                    Workspace(id: $0, applications: snapshot.apps[$0, default: []], isActive: $0 == snapshot.active)
                }
                selection = workspaces.first(where: \.isActive)?.id ?? workspaces.first?.id
                errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func move(by offset: Int) {
        guard !workspaces.isEmpty else { return }
        let current = workspaces.firstIndex { $0.id == selection } ?? 0
        selection = workspaces[(current + offset + workspaces.count) % workspaces.count].id
    }
    func selectFirst() { selection = workspaces.first?.id }
    func selectLast() { selection = workspaces.last?.id }
    func select(_ id: String) -> Bool { guard workspaces.contains(where: { $0.id == id }) else { return false }; selection = id; return true }
    func activate(_ id: String) { Task { do { try await AeroSpaceClient.activate(id) } catch { errorMessage = error.localizedDescription } } }
}

private enum AeroSpaceClient {
    struct Snapshot: Sendable { let active: String; let apps: [String: [WorkspaceApplication]] }

    static func snapshot() async throws -> Snapshot {
        async let active = run(["list-workspaces", "--focused"])
        async let windows = run(["list-windows", "--all", "--format", "%{workspace}%{tab}%{app-name}"])
        let apps = AeroSpaceOutputParser.applicationsByWorkspace(try await windows)
        return try await Snapshot(active: active.trimmingCharacters(in: .whitespacesAndNewlines), apps: apps)
    }

    static func activate(_ id: String) async throws { _ = try await run(["workspace", id]) }

    static func run(_ arguments: [String]) async throws -> String {
        let candidates = ["/opt/homebrew/bin/aerospace", "/usr/local/bin/aerospace"]
        guard let path = candidates.first(where: FileManager.default.isExecutableFile(atPath:)) else { throw ClientError.notFound }
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process(), output = Pipe(), errors = Pipe()
            process.executableURL = URL(fileURLWithPath: path); process.arguments = arguments
            process.standardOutput = output; process.standardError = errors
            process.terminationHandler = { process in
                let stdout = output.fileHandleForReading.readDataToEndOfFile()
                let stderr = errors.fileHandleForReading.readDataToEndOfFile()
                process.terminationStatus == 0
                    ? continuation.resume(returning: String(decoding: stdout, as: UTF8.self))
                    : continuation.resume(throwing: ClientError.failed(String(decoding: stderr, as: UTF8.self)))
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }

    enum ClientError: LocalizedError {
        case notFound, failed(String)
        var errorDescription: String? { switch self { case .notFound: "AeroSpace CLI was not found."; case .failed(let message): message } }
    }
}

enum AeroSpaceOutputParser {
    static func applicationsByWorkspace(_ output: String) -> [String: [WorkspaceApplication]] {
        var counts: [String: [String: Int]] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { continue }
            let workspace = String(fields[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let app = String(fields[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !workspace.isEmpty, !app.isEmpty else { continue }
            counts[workspace, default: [:]][app, default: 0] += 1
        }

        return counts.mapValues { apps in
            apps.map { WorkspaceApplication(name: $0.key, windowCount: $0.value) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }
}
