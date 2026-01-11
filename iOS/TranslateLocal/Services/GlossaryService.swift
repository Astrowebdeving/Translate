//
//  GlossaryService.swift
//  TranslateLocal
//
//  Custom glossary for user-defined translations
//  Supports automatic name/term detection using NLP
//

import Foundation
import NaturalLanguage

// MARK: - Glossary Entry

/// A custom translation rule
struct GlossaryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var sourceText: String           // Original text to match
    var targetText: String           // Custom translation
    var sourceLanguage: String?      // Optional: specific source language
    var targetLanguage: String?      // Optional: specific target language
    var isCaseSensitive: Bool        // Match case exactly
    var isEnabled: Bool              // Can be toggled on/off
    var category: GlossaryCategory   // Type of entry
    var notes: String?               // User notes
    var createdAt: Date
    var usageCount: Int              // Track how often used
    
    init(
        id: UUID = UUID(),
        sourceText: String,
        targetText: String,
        sourceLanguage: String? = nil,
        targetLanguage: String? = nil,
        isCaseSensitive: Bool = true,
        isEnabled: Bool = true,
        category: GlossaryCategory = .custom,
        notes: String? = nil,
        createdAt: Date = Date(),
        usageCount: Int = 0
    ) {
        self.id = id
        self.sourceText = sourceText
        self.targetText = targetText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.isCaseSensitive = isCaseSensitive
        self.isEnabled = isEnabled
        self.category = category
        self.notes = notes
        self.createdAt = createdAt
        self.usageCount = usageCount
    }
}

/// Categories for glossary entries
enum GlossaryCategory: String, Codable, CaseIterable {
    case name = "Names"              // Character/person names
    case place = "Places"            // Location names
    case term = "Terms"              // Special terminology
    case honorific = "Honorifics"    // -san, -kun, sensei, etc.
    case custom = "Custom"           // User-defined
    case autoDetected = "Auto-Detected"  // AI-suggested
    
    var icon: String {
        switch self {
        case .name: return "person.fill"
        case .place: return "mappin.circle.fill"
        case .term: return "text.book.closed.fill"
        case .honorific: return "person.badge.key.fill"
        case .custom: return "pencil.circle.fill"
        case .autoDetected: return "sparkles"
        }
    }
    
    var color: String {
        switch self {
        case .name: return "blue"
        case .place: return "green"
        case .term: return "purple"
        case .honorific: return "orange"
        case .custom: return "indigo"
        case .autoDetected: return "pink"
        }
    }
}

// MARK: - Detected Term

/// A term detected by NLP that might need custom translation
struct DetectedTerm: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let category: DetectedTermType
    let confidence: Double
    let range: Range<String.Index>
    let context: String  // Surrounding text for context
    
    var suggestedCategory: GlossaryCategory {
        switch category {
        case .personalName: return .name
        case .placeName: return .place
        case .organizationName: return .term
        case .unknown: return .custom
        }
    }
}

enum DetectedTermType: String {
    case personalName = "Person"
    case placeName = "Place"
    case organizationName = "Organization"
    case unknown = "Unknown"
}

// MARK: - Glossary Service

@MainActor @Observable
class GlossaryService {
    
    // MARK: - Observable Properties
    
    private(set) var entries: [GlossaryEntry] = []
    private(set) var detectedTerms: [DetectedTerm] = []
    private(set) var isAnalyzing = false
    
    // MARK: - Private Properties
    
    private let storageKey = "translatelocal.glossary"
    private let userDefaults = UserDefaults.standard
    private let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass, .language])
    
    // MARK: - Initialization
    
    init() {
        loadEntries()
    }
    
    // MARK: - Entry Management
    
    /// Add a new glossary entry
    func addEntry(_ entry: GlossaryEntry) {
        entries.append(entry)
        saveEntries()
    }
    
    /// Add entry from detected term
    func addEntry(from term: DetectedTerm, targetText: String) {
        let entry = GlossaryEntry(
            sourceText: term.text,
            targetText: targetText,
            category: term.suggestedCategory,
            notes: "Auto-detected from: \(term.context)"
        )
        addEntry(entry)
    }
    
    /// Update an existing entry
    func updateEntry(_ entry: GlossaryEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            saveEntries()
        }
    }
    
    /// Delete an entry
    func deleteEntry(_ entry: GlossaryEntry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
    }
    
    /// Delete entries by IDs
    func deleteEntries(ids: Set<UUID>) {
        entries.removeAll { ids.contains($0.id) }
        saveEntries()
    }
    
    /// Toggle entry enabled state
    func toggleEntry(_ entry: GlossaryEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index].isEnabled.toggle()
            saveEntries()
        }
    }
    
    /// Increment usage count
    func incrementUsage(for entry: GlossaryEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index].usageCount += 1
            // Note: saveEntries() is called separately via batchIncrementUsage
        }
    }
    
    /// Batch increment usage counts and save once (more efficient)
    func batchIncrementUsage(for usedEntries: [GlossaryEntry]) {
        for entry in usedEntries {
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[index].usageCount += 1
            }
        }
        // Save once after all updates
        if !usedEntries.isEmpty {
            saveEntries()
        }
    }
    
    // MARK: - Translation Application
    
    /// Apply glossary to text before/after translation
    func applyGlossary(
        to text: String,
        sourceLanguage: String? = nil,
        targetLanguage: String? = nil,
        phase: GlossaryPhase = .preTranslation
    ) -> (text: String, appliedEntries: [GlossaryEntry]) {
        var result = text
        var applied: [GlossaryEntry] = []
        
        // Get applicable entries
        let applicableEntries = entries.filter { entry in
            guard entry.isEnabled else { return false }
            
            // Check language match if specified
            if let sourceLang = sourceLanguage,
               let entrySourceLang = entry.sourceLanguage,
               sourceLang != entrySourceLang {
                return false
            }
            
            if let targetLang = targetLanguage,
               let entryTargetLang = entry.targetLanguage,
               targetLang != entryTargetLang {
                return false
            }
            
            return true
        }
        
        // Sort by length (longest first to avoid partial matches)
        let sortedEntries = applicableEntries.sorted {
            $0.sourceText.count > $1.sourceText.count
        }
        
        // Apply each entry
        for entry in sortedEntries {
            let searchText = entry.isCaseSensitive ? entry.sourceText : entry.sourceText.lowercased()
            let compareText = entry.isCaseSensitive ? result : result.lowercased()
            
            if compareText.contains(searchText) {
                // Use word boundaries for better matching
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: entry.sourceText))\\b"
                let options: NSRegularExpression.Options = entry.isCaseSensitive ? [] : .caseInsensitive
                
                if let regex = try? NSRegularExpression(pattern: pattern, options: options) {
                    let range = NSRange(result.startIndex..., in: result)
                    let matches = regex.numberOfMatches(in: result, range: range)
                    
                    if matches > 0 {
                        result = regex.stringByReplacingMatches(
                            in: result,
                            range: range,
                            withTemplate: entry.targetText
                        )
                        applied.append(entry)
                    }
                }
            }
        }
        
        return (result, applied)
    }
    
    // MARK: - Name/Term Detection (NLP)
    
    /// Maximum characters to analyze (prevents freezing on huge texts)
    private let maxAnalysisLength = 10_000
    
    /// Analyze text for names and key terms using NLP
    func analyzeText(_ text: String) async -> [DetectedTerm] {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        var detected: [DetectedTerm] = []
        
        // Limit text length to prevent performance issues
        let textToAnalyze = text.count > maxAnalysisLength 
            ? String(text.prefix(maxAnalysisLength)) 
            : text
        
        tagger.string = textToAnalyze
        
        // Detect named entities (people, places, organizations)
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        
        tagger.enumerateTags(
            in: textToAnalyze.startIndex..<textToAnalyze.endIndex,
            unit: .word,
            scheme: .nameType,
            options: options
        ) { tag, tokenRange in
            
            guard let tag = tag else { return true }
            
            let word = String(textToAnalyze[tokenRange])
            
            // Skip very short words
            guard word.count >= 2 else { return true }
            
            // Determine term type
            let termType: DetectedTermType
            switch tag {
            case .personalName:
                termType = .personalName
            case .placeName:
                termType = .placeName
            case .organizationName:
                termType = .organizationName
            default:
                return true  // Skip other types
            }
            
            // Get surrounding context (safely)
            let contextStart = textToAnalyze.index(tokenRange.lowerBound, offsetBy: -30, limitedBy: textToAnalyze.startIndex) ?? textToAnalyze.startIndex
            let contextEnd = textToAnalyze.index(tokenRange.upperBound, offsetBy: 30, limitedBy: textToAnalyze.endIndex) ?? textToAnalyze.endIndex
            let context = String(textToAnalyze[contextStart..<contextEnd])
            
            let term = DetectedTerm(
                text: word,
                category: termType,
                confidence: 0.8,  // NLTagger doesn't provide confidence
                range: tokenRange,
                context: "...\(context)..."
            )
            
            // Only add if not already in glossary and not duplicate
            let isInGlossary = self.entries.contains { $0.sourceText.lowercased() == word.lowercased() }
            let isDuplicate = detected.contains { $0.text.lowercased() == word.lowercased() }
            
            if !isInGlossary && !isDuplicate {
                detected.append(term)
            }
            
            return true
        }
        
        // Also detect potential Japanese names (kanji sequences) - use truncated text
        detected.append(contentsOf: detectJapaneseNames(in: textToAnalyze, existing: detected))
        
        self.detectedTerms = detected
        return detected
    }
    
    /// Detect potential Japanese names (kanji character sequences)
    /// Limited to first 50 matches to prevent performance issues
    private func detectJapaneseNames(in text: String, existing: [DetectedTerm]) -> [DetectedTerm] {
        var detected: [DetectedTerm] = []
        let maxMatches = 50  // Limit to prevent performance issues
        
        // Pattern for 2-4 kanji (common name length)
        let kanjiPattern = "[\\u4E00-\\u9FFF]{2,4}"
        
        guard let regex = try? NSRegularExpression(pattern: kanjiPattern) else {
            return []
        }
        
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range).prefix(maxMatches)
        
        for match in matches {
            guard let swiftRange = Range(match.range, in: text) else { continue }
            let word = String(text[swiftRange])
            
            // Skip if already detected or in glossary
            let isInGlossary = entries.contains { $0.sourceText == word }
            let isDuplicate = existing.contains { $0.text == word } || detected.contains { $0.text == word }
            
            if !isInGlossary && !isDuplicate {
                // Get context
                let contextStart = text.index(swiftRange.lowerBound, offsetBy: -20, limitedBy: text.startIndex) ?? text.startIndex
                let contextEnd = text.index(swiftRange.upperBound, offsetBy: 20, limitedBy: text.endIndex) ?? text.endIndex
                let context = String(text[contextStart..<contextEnd])
                
                let term = DetectedTerm(
                    text: word,
                    category: .personalName,  // Assume name for kanji sequences
                    confidence: 0.6,
                    range: swiftRange,
                    context: "...\(context)..."
                )
                detected.append(term)
            }
        }
        
        return detected
    }
    
    /// Clear detected terms
    func clearDetectedTerms() {
        detectedTerms = []
    }
    
    // MARK: - Persistence
    
    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            userDefaults.set(data, forKey: storageKey)
        }
    }
    
    private func loadEntries() {
        if let data = userDefaults.data(forKey: storageKey),
           let loaded = try? JSONDecoder().decode([GlossaryEntry].self, from: data) {
            entries = loaded
        }
    }
    
    // MARK: - Import/Export
    
    /// Export glossary to JSON
    func exportToJSON() -> Data? {
        try? JSONEncoder().encode(entries)
    }
    
    /// Import glossary from JSON
    func importFromJSON(_ data: Data, merge: Bool = true) throws {
        let imported = try JSONDecoder().decode([GlossaryEntry].self, from: data)
        
        if merge {
            // Merge, avoiding duplicates
            for entry in imported {
                if !entries.contains(where: { $0.sourceText == entry.sourceText }) {
                    entries.append(entry)
                }
            }
        } else {
            entries = imported
        }
        
        saveEntries()
    }
    
    /// Export to CSV format
    func exportToCSV() -> String {
        var csv = "Source,Target,Category,Case Sensitive,Notes\n"
        
        for entry in entries {
            let source = entry.sourceText.replacingOccurrences(of: ",", with: "\\,")
            let target = entry.targetText.replacingOccurrences(of: ",", with: "\\,")
            let notes = (entry.notes ?? "").replacingOccurrences(of: ",", with: "\\,")
            
            csv += "\"\(source)\",\"\(target)\",\"\(entry.category.rawValue)\",\(entry.isCaseSensitive),\"\(notes)\"\n"
        }
        
        return csv
    }
    
    // MARK: - Presets
    
    /// Add common Japanese honorifics
    func addJapaneseHonorificsPreset() {
        let honorifics: [(String, String, String?)] = [
            ("-san", "-san", "Polite suffix (Mr./Ms.)"),
            ("-kun", "-kun", "Familiar suffix (usually male)"),
            ("-chan", "-chan", "Affectionate suffix"),
            ("-sama", "-sama", "Very respectful suffix"),
            ("-sensei", "-sensei", "Teacher/master"),
            ("-senpai", "-senpai", "Senior"),
            ("-kouhai", "-kouhai", "Junior"),
            ("-dono", "-dono", "Archaic respectful suffix"),
            ("onii-san", "onii-san", "Older brother"),
            ("onee-san", "onee-san", "Older sister"),
            ("ojii-san", "ojii-san", "Grandfather/old man"),
            ("obaa-san", "obaa-san", "Grandmother/old woman"),
        ]

        for (source, target, notes) in honorifics {
            if !entries.contains(where: { $0.sourceText == source }) {
                let entry = GlossaryEntry(
                    sourceText: source,
                    targetText: target,
                    isCaseSensitive: false,
                    category: .honorific,
                    notes: notes
                )
                entries.append(entry)
            }
        }

        saveEntries()
    }

    /// Add common Japanese words/phrases with English translations
    func addJapaneseToEnglishPreset() {
        let japaneseToEnglish: [(String, String, String?)] = [
            // Common phrases
            ("こんにちは", "konnichiwa", "Hello/Good afternoon"),
            ("ありがとう", "arigatou", "Thank you"),
            ("すみません", "sumimasen", "Excuse me/Sorry"),
            ("お願いします", "onegaishimasu", "Please"),
            ("はい", "hai", "Yes"),
            ("いいえ", "iie", "No"),
            ("わかりました", "wakarimashita", "I understand"),
            ("すみません", "gomennasai", "I'm sorry"),

            // Common words
            ("学校", "gakkou", "School"),
            ("先生", "sensei", "Teacher"),
            ("学生", "gakusei", "Student"),
            ("友達", "tomodachi", "Friend"),
            ("家族", "kazoku", "Family"),
            ("食べ物", "tabemono", "Food"),
            ("飲み物", "nomimono", "Drink"),
            ("時間", "jikan", "Time"),
            ("今日", "kyou", "Today"),
            ("明日", "ashita", "Tomorrow"),
            ("昨日", "kinou", "Yesterday"),

            // Honorifics (for context)
            ("さん", "san", "Polite suffix"),
            ("くん", "kun", "Familiar suffix (male)"),
            ("ちゃん", "chan", "Affectionate suffix"),
            ("様", "sama", "Very respectful suffix"),
        ]

        for (source, target, notes) in japaneseToEnglish {
            if !entries.contains(where: { $0.sourceText == source }) {
                let entry = GlossaryEntry(
                    sourceText: source,
                    targetText: target,
                    sourceLanguage: "ja",
                    targetLanguage: "en",
                    isCaseSensitive: false,
                    category: .term,
                    notes: notes
                )
                entries.append(entry)
            }
        }

        saveEntries()
    }
}

// MARK: - Glossary Phase

enum GlossaryPhase {
    case preTranslation   // Apply before translation (protect terms)
    case postTranslation  // Apply after translation (fix known issues)
}

// MARK: - Statistics

extension GlossaryService {
    
    var totalEntries: Int { entries.count }
    
    var enabledEntries: Int { entries.filter { $0.isEnabled }.count }
    
    var entriesByCategory: [GlossaryCategory: Int] {
        Dictionary(grouping: entries, by: { $0.category })
            .mapValues { $0.count }
    }
    
    var mostUsedEntries: [GlossaryEntry] {
        entries.sorted { $0.usageCount > $1.usageCount }.prefix(10).map { $0 }
    }
}
