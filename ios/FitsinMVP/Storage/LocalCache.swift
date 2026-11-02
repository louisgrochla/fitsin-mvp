import Foundation

enum LocalCache {
    private static var baseURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    static func write<T: Encodable>(_ value: T, key: String) {
        let url = baseURL.appendingPathComponent(key)
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            print("cache write failed: \(error)")
        }
    }

    static func read<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let url = baseURL.appendingPathComponent(key)
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }
}
