import Foundation

struct AeroSpaceWindow: Identifiable, Equatable, Sendable {
    let id: Int
    let workspaceID: String
    let applicationName: String
    let title: String

    var displayTitle: String { title.isEmpty ? "Untitled Window" : title }
}

struct WorkspaceApplication: Identifiable, Equatable, Sendable {
    var id: String { name }
    let name: String
    let windowCount: Int
}

struct Workspace: Identifiable, Equatable, Sendable {
    let id: String
    let windows: [AeroSpaceWindow]
    let isActive: Bool

    var applications: [WorkspaceApplication] {
        Dictionary(grouping: windows, by: \.applicationName)
            .map { WorkspaceApplication(name: $0.key, windowCount: $0.value.count) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    var windowCount: Int { windows.count }
    var isEmpty: Bool { windows.isEmpty }
}

enum WorkspaceSelection: Hashable {
    case workspace(String)
    case window(Int)
}

@MainActor
final class WorkspaceModel: ObservableObject {
    static let workspaceIDs = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "C", "N"]

    @Published private(set) var workspaces: [Workspace]
    @Published private(set) var selection: WorkspaceSelection?
    @Published private(set) var expandedWorkspaceID: String?
    @Published private(set) var errorMessage: String?

    init(workspaces: [Workspace] = [], selection: WorkspaceSelection? = nil) {
        self.workspaces = workspaces
        self.selection = selection
    }

    var visibleItems: [WorkspaceSelection] {
        workspaces.flatMap { workspace in
            var items: [WorkspaceSelection] = [.workspace(workspace.id)]
            if expandedWorkspaceID == workspace.id {
                items.append(contentsOf: workspace.windows.map { .window($0.id) })
            }
            return items
        }
    }

    func refresh() {
        Task {
            do {
                let snapshot = try await AeroSpaceClient.snapshot()
                workspaces = Self.workspaceIDs.map {
                    Workspace(id: $0, windows: snapshot.windows[$0, default: []], isActive: $0 == snapshot.active)
                }
                expandedWorkspaceID = nil
                selection = .workspace(workspaces.first(where: \.isActive)?.id ?? workspaces.first?.id ?? "")
                errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func move(by offset: Int) {
        let items = visibleItems
        guard !items.isEmpty else { return }
        let current = selection.flatMap(items.firstIndex(of:)) ?? 0
        selection = items[(current + offset + items.count) % items.count]
    }

    func selectFirst() { selection = visibleItems.first }
    func selectLast() { selection = visibleItems.last }

    func expandSelection() {
        guard case let .workspace(id) = selection,
              let workspace = workspaces.first(where: { $0.id == id }),
              !workspace.isEmpty else { return }
        expandedWorkspaceID = id
    }

    func collapseSelection() {
        switch selection {
        case let .workspace(id) where expandedWorkspaceID == id:
            expandedWorkspaceID = nil
        case let .window(windowID):
            guard let workspace = workspaces.first(where: { workspace in
                workspace.windows.contains(where: { $0.id == windowID })
            }) else { return }
            selection = .workspace(workspace.id)
            expandedWorkspaceID = nil
        default:
            break
        }
    }

    func selectWorkspace(_ id: String) -> Bool {
        guard workspaces.contains(where: { $0.id == id }) else { return false }
        selection = .workspace(id)
        return true
    }

    func activateSelection() {
        switch selection {
        case let .workspace(id): activateWorkspace(id)
        case let .window(id): activateWindow(id)
        case nil: break
        }
    }

    func activateWorkspace(_ id: String) {
        runActivation { try await AeroSpaceClient.activateWorkspace(id) }
    }

    private func activateWindow(_ id: Int) {
        runActivation { try await AeroSpaceClient.activateWindow(id) }
    }

    private func runActivation(_ operation: @escaping @Sendable () async throws -> Void) {
        Task {
            do { try await operation() }
            catch { errorMessage = error.localizedDescription }
        }
    }
}

private enum AeroSpaceClient {
    struct Snapshot: Sendable { let active: String; let windows: [String: [AeroSpaceWindow]] }

    static func snapshot() async throws -> Snapshot {
        async let active = run(["list-workspaces", "--focused"])
        async let windows = run([
            "list-windows", "--all", "--format",
            "%{window-id}%{tab}%{workspace}%{tab}%{app-name}%{tab}%{window-title}"
        ])
        let parsedWindows = AeroSpaceOutputParser.windows(try await windows)
        return try await Snapshot(
            active: active.trimmingCharacters(in: .whitespacesAndNewlines),
            windows: Dictionary(grouping: parsedWindows, by: \.workspaceID)
        )
    }

    static func activateWorkspace(_ id: String) async throws { _ = try await run(AeroSpaceCommand.workspace(id).arguments) }
    static func activateWindow(_ id: Int) async throws { _ = try await run(AeroSpaceCommand.window(id).arguments) }

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
        var errorDescription: String? {
            switch self {
            case .notFound: "AeroSpace CLI was not found."
            case .failed(let message): message.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
}

enum AeroSpaceCommand: Equatable {
    case workspace(String)
    case window(Int)

    var arguments: [String] {
        switch self {
        case let .workspace(id): ["workspace", id]
        case let .window(id): ["focus", "--window-id", String(id)]
        }
    }
}

enum AeroSpaceOutputParser {
    static func windows(_ output: String) -> [AeroSpaceWindow] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)
            guard fields.count == 4,
                  let id = Int(fields[0].trimmingCharacters(in: .whitespaces)),
                  !fields[1].isEmpty, !fields[2].isEmpty else { return nil }
            return AeroSpaceWindow(
                id: id,
                workspaceID: String(fields[1]),
                applicationName: String(fields[2]),
                title: String(fields[3]).trimmingCharacters(in: .whitespaces)
            )
        }
    }

    static func applicationsByWorkspace(_ output: String) -> [String: [WorkspaceApplication]] {
        Dictionary(grouping: windows(output), by: \.workspaceID).mapValues { windows in
            Dictionary(grouping: windows, by: \.applicationName)
                .map { WorkspaceApplication(name: $0.key, windowCount: $0.value.count) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }
}
