import XCTest
import UniformTypeIdentifiers
@testable import Trace

/// The single "Import Entries" action routes a picked file to either the Trace
/// JSON importer or the Quick Journal `.txt` importer. This pins that decision
/// (the underlying importers themselves are covered by `JournalActionsTests`
/// and `QuickJournalImportTests`).
final class JournalImportRoutingTests: XCTestCase {

    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { [dir] in try? FileManager.default.removeItem(at: dir!) }
    }

    private func file(_ name: String, _ contents: String = "x") throws -> URL {
        let url = dir.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testJSONExtensionRoutesToTraceJSON() throws {
        XCTAssertEqual(JournalSettingsView.fileKind(of: try file("trace-journal-export.json", "[]")), .traceJSON)
    }

    func testTxtExtensionRoutesToQuickJournal() throws {
        XCTAssertEqual(JournalSettingsView.fileKind(of: try file("quick-journal.txt")), .quickJournalText)
    }

    func testExtensionWinsRegardlessOfCase() throws {
        XCTAssertEqual(JournalSettingsView.fileKind(of: try file("EXPORT.JSON", "[]")), .traceJSON)
        XCTAssertEqual(JournalSettingsView.fileKind(of: try file("EXPORT.TXT")), .quickJournalText)
    }

    func testUndeterminableTypeRoutesToUnknown() throws {
        // No extension, generic bytes → public.data → not a supported type,
        // so the router reports an error rather than guessing a format.
        XCTAssertEqual(JournalSettingsView.fileKind(of: try file("mystery")), .unknown)
    }

    func testPlainTextWithoutTxtExtensionStillRoutesToQuickJournalViaUTI() throws {
        // A .text file conforms to public.plain-text; the UTI branch catches it.
        let url = try file("notes.text")
        XCTAssertTrue((try url.resourceValues(forKeys: [.contentTypeKey]).contentType)?.conforms(to: .plainText) ?? false)
        XCTAssertEqual(JournalSettingsView.fileKind(of: url), .quickJournalText)
    }
}
