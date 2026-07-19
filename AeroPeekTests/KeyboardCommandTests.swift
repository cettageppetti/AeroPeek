import AppKit
import XCTest
@testable import AeroPeek

final class KeyboardCommandTests: XCTestCase {
    func testEndRepresentations() {
        XCTAssertEqual(map(119), .selectLast)
        XCTAssertEqual(map(0, String(UnicodeScalar(NSEndFunctionKey)!)), .selectLast)
    }
    func testHomeRepresentations() {
        XCTAssertEqual(map(115), .selectFirst)
        XCTAssertEqual(map(0, String(UnicodeScalar(NSHomeFunctionKey)!)), .selectFirst)
    }
    func testNavigation() {
        XCTAssertEqual(map(125), .moveSelection(1)); XCTAssertEqual(map(126), .moveSelection(-1))
        XCTAssertEqual(map(124), .expandSelection); XCTAssertEqual(map(123), .collapseSelection)
        XCTAssertEqual(map(124, nil, .function), .expandSelection)
        XCTAssertEqual(map(123, nil, .function), .collapseSelection)
        XCTAssertEqual(map(36), .activateSelection); XCTAssertEqual(map(53), .dismiss)
    }
    func testQuitShortcut() {
        XCTAssertEqual(map(12, "q", .command), .quit)
        XCTAssertEqual(map(12, "q"), .activateWorkspace("Q"))
    }
    func testTypeToSelect() {
        for key in ["1", "9", "a", "B", "n"] { XCTAssertEqual(map(0, key), .activateWorkspace(key.uppercased())) }
        XCTAssertNil(map(0, "A", .option)); XCTAssertNil(map(0, "-")); XCTAssertNil(map(0, "AB"))
    }
    func testTabIsNotAnOverlayCommand() {
        XCTAssertNil(map(48, "\t"))
    }
    private func map(_ code: UInt16, _ characters: String? = nil, _ modifiers: NSEvent.ModifierFlags = []) -> KeyboardCommand? {
        KeyboardCommandMapper.command(for: KeyInput(keyCode: code, characters: characters, modifiers: modifiers))
    }
}

@MainActor
final class OverlayPanelCommandTests: XCTestCase {
    func testResponderChainNavigationCommandsAreForwarded() {
        let panel = OverlayPanel()
        var commands: [KeyboardCommand] = []
        panel.handleCommand = { commands.append($0) }

        panel.moveDown(nil)
        panel.moveUp(nil)
        panel.moveRight(nil)
        panel.moveLeft(nil)
        panel.insertNewline(nil)

        XCTAssertEqual(commands, [
            .moveSelection(1), .moveSelection(-1), .expandSelection,
            .collapseSelection, .activateSelection
        ])
    }
}

final class AeroSpaceOutputParserTests: XCTestCase {
    func testParsesConfiguredWorkspaceIDsInAeroSpaceOrder() {
        XCTAssertEqual(AeroSpaceOutputParser.workspaceIDs("dev\n2\nN\n"), ["dev", "2", "N"])
    }

    func testGroupsApplicationsAndCountsEveryWindow() {
        let output = """
        101\t1\tSafari\tDocumentation
        102\t1\tSafari\tRelease Notes
        103\t1\tTerminal\tssh prod
        104\t3\tFinder\t
        """

        let result = AeroSpaceOutputParser.applicationsByWorkspace(output)

        XCTAssertEqual(result["1"], [
            WorkspaceApplication(name: "Safari", windowCount: 2),
            WorkspaceApplication(name: "Terminal", windowCount: 1)
        ])
        XCTAssertEqual(result["3"], [WorkspaceApplication(name: "Finder", windowCount: 1)])
    }

    func testIgnoresMalformedAndEmptyRows() {
        let result = AeroSpaceOutputParser.applicationsByWorkspace("bad row\nabc\t2\tSafari\tTitle\n2\t\tFinder\tTitle\n")
        XCTAssertTrue(result.isEmpty)
    }

    func testParsesWindowIdentityAndTitle() {
        XCTAssertEqual(AeroSpaceOutputParser.windows("42\t3\tTerminal\tssh prod\n"), [
            AeroSpaceWindow(id: 42, workspaceID: "3", applicationName: "Terminal", title: "ssh prod")
        ])
    }
}

final class AeroSpaceCommandTests: XCTestCase {
    func testWindowActivationUsesStableWindowID() {
        XCTAssertEqual(AeroSpaceCommand.window(42).arguments, ["focus", "--window-id", "42"])
    }

    func testWorkspaceActivationIsPreserved() {
        XCTAssertEqual(AeroSpaceCommand.workspace("N").arguments, ["workspace", "N"])
    }
}

@MainActor
final class WorkspaceNavigationTests: XCTestCase {
    private let windows = [
        AeroSpaceWindow(id: 10, workspaceID: "1", applicationName: "Terminal", title: "ssh"),
        AeroSpaceWindow(id: 11, workspaceID: "1", applicationName: "Terminal", title: "logs")
    ]

    func testExpandAndNavigateVisibleHierarchy() {
        let model = makeModel()
        model.expandSelection()

        XCTAssertEqual(model.expandedWorkspaceID, "1")
        XCTAssertEqual(model.visibleItems, [.workspace("1"), .window(10), .window(11), .workspace("2")])

        model.move(by: 1)
        XCTAssertEqual(model.selection, .window(10))
    }

    func testCollapseFromChildReturnsToParent() {
        let model = makeModel()
        model.expandSelection()
        model.move(by: 1)
        model.collapseSelection()

        XCTAssertEqual(model.selection, .workspace("1"))
        XCTAssertNil(model.expandedWorkspaceID)
    }

    func testEmptyWorkspaceDoesNotExpand() {
        let model = makeModel(selection: .workspace("2"))
        model.expandSelection()
        XCTAssertNil(model.expandedWorkspaceID)
    }

    private func makeModel(selection: WorkspaceSelection = .workspace("1")) -> WorkspaceModel {
        WorkspaceModel(workspaces: [
            Workspace(id: "1", windows: windows, isActive: true),
            Workspace(id: "2", windows: [], isActive: false)
        ], selection: selection)
    }
}
