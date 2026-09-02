import Foundation

/// Shared plumbing for the app's local export/import files. Nothing here
/// talks to a server — this is file-based data portability (export to a
/// JSON file, import that file back in), not sync.
enum JSONExport {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Encodes `payload` and writes it to a temp file named `filename`,
    /// ready to hand to `ShareLink`. `nil` on any encode/write failure.
    static func writeTempFile<T: Encodable>(_ payload: T, filename: String) -> URL? {
        guard let data = try? encoder.encode(payload) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
