//
//  AppGroupConstants.swift
//  TranslateLocal
//
//  Shared constants for App Group communication between main app and extensions
//

import Foundation

/// Constants for App Group shared container
enum AppGroupConstants {
    /// The App Group identifier used for sharing data between app and extensions
    static let suiteName = "group.com.translatelocal.shared"
    
    /// File names for shared data
    static let screenPayloadFileName = "screen_payload.json"
    static let translationResultFileName = "translation_result.json"
    static let settingsFileName = "shared_settings.json"
    
    /// UserDefaults keys for shared settings
    static let sourceLanguageKey = "sourceLanguage"
    static let targetLanguageKey = "targetLanguage"
    static let isScreenModeActiveKey = "isScreenModeActive"
    static let lastUpdateTimestampKey = "lastUpdateTimestamp"
    
    /// Get the shared container URL for App Group
    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
    }
    
    /// Get URL for a specific file in the shared container
    static func fileURL(for fileName: String) -> URL? {
        sharedContainerURL?.appendingPathComponent(fileName)
    }
    
    /// Shared UserDefaults for App Group
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}

/// Extension to simplify reading/writing shared data
extension AppGroupConstants {
    
    /// Save Codable data to shared container
    static func save<T: Encodable>(_ data: T, to fileName: String) throws {
        guard let url = fileURL(for: fileName) else {
            throw AppGroupError.containerNotAvailable
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(data)
        
        // Atomic write to prevent partial reads
        try jsonData.write(to: url, options: .atomic)
    }
    
    /// Load Codable data from shared container
    static func load<T: Decodable>(_ type: T.Type, from fileName: String) throws -> T {
        guard let url = fileURL(for: fileName) else {
            throw AppGroupError.containerNotAvailable
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
    
    /// Check if a file exists in shared container
    static func fileExists(_ fileName: String) -> Bool {
        guard let url = fileURL(for: fileName) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Delete a file from shared container
    static func deleteFile(_ fileName: String) throws {
        guard let url = fileURL(for: fileName) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    /// Get file modification date
    static func fileModificationDate(_ fileName: String) -> Date? {
        guard let url = fileURL(for: fileName) else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date
    }
}

/// Errors for App Group operations
enum AppGroupError: LocalizedError {
    case containerNotAvailable
    case fileNotFound
    case encodingFailed
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .containerNotAvailable:
            return "App Group container is not available"
        case .fileNotFound:
            return "File not found in shared container"
        case .encodingFailed:
            return "Failed to encode data"
        case .decodingFailed:
            return "Failed to decode data"
        }
    }
}
