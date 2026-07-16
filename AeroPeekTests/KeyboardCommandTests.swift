import AppKit
import XCTest
@testable import AeroPeek

final class KeyboardCommandTests: XCTestCase {
    func testEndRepresentations() {
        XCTAssertEqual(map(119), .selectLast)
        XCTAssertEqual(map(0, String(UnicodeScalar(NSEndFunctionKey)!)), .selectLast)
        XCTAssertEqual(map(124, nil, .function), .selectLast)
    }
    func testHomeRepresentations() {
        XCTAssertEqual(map(115), .selectFirst)
        XCTAssertEqual(map(0, String(UnicodeScalar(NSHomeFunctionKey)!)), .selectFirst)
        XCTAssertEqual(map(123, nil, .function), .selectFirst)
    }
    func testNavigation() {
        XCTAssertEqual(map(125), .moveSelection(1)); XCTAssertEqual(map(126), .moveSelection(-1))
        XCTAssertEqual(map(36), .activateSelection); XCTAssertEqual(map(53), .dismiss)
    }
    func testTypeToSelect() {
        for key in ["1", "9", "a", "C", "n"] { XCTAssertEqual(map(0, key), .activateWorkspace(key.uppercased())) }
        XCTAssertNil(map(0, "A", .option)); XCTAssertNil(map(0, "B"))
    }
    private func map(_ code: UInt16, _ characters: String? = nil, _ modifiers: NSEvent.ModifierFlags = []) -> KeyboardCommand? {
        KeyboardCommandMapper.command(for: KeyInput(keyCode: code, characters: characters, modifiers: modifiers))
    }
}

final class AeroSpaceOutputParserTests: XCTestCase {
    func testGroupsApplicationsAndCountsEveryWindow() {
        let output = """
        1\tSafari
        1\tSafari
        1\tTerminal
        3\tFinder
        """

        let result = AeroSpaceOutputParser.applicationsByWorkspace(output)

        XCTAssertEqual(result["1"], [
            WorkspaceApplication(name: "Safari", windowCount: 2),
            WorkspaceApplication(name: "Terminal", windowCount: 1)
        ])
        XCTAssertEqual(result["3"], [WorkspaceApplication(name: "Finder", windowCount: 1)])
    }

    func testIgnoresMalformedAndEmptyRows() {
        let result = AeroSpaceOutputParser.applicationsByWorkspace("bad row\n2\t\n\tFinder\n")
        XCTAssertTrue(result.isEmpty)
    }
}
