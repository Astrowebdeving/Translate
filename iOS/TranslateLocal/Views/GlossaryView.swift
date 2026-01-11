//
//  GlossaryView.swift
//  TranslateLocal
//
//  UI for managing custom glossary entries and term detection
//

import SwiftUI

struct GlossaryView: View {
    @Environment(AppState.self) var appState
    @State private var glossaryService = GlossaryService()
    
    @State private var showingAddEntry = false
    @State private var showingAnalyzer = false
    @State private var searchText = ""
    @State private var selectedCategory: GlossaryCategory?
    @State private var editingEntry: GlossaryEntry?
    
    var filteredEntries: [GlossaryEntry] {
        var entries = glossaryService.entries
        
        // Filter by category
        if let category = selectedCategory {
            entries = entries.filter { $0.category == category }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            entries = entries.filter {
                $0.sourceText.localizedCaseInsensitiveContains(searchText) ||
                $0.targetText.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return entries.sorted { $0.sourceText < $1.sourceText }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Stats section
                if !glossaryService.entries.isEmpty {
                    statsSection
                }
                
                // Category filter
                categoryFilterSection
                
                // Entries
                entriesSection
                
                // Quick actions
                quickActionsSection
            }
            .searchable(text: $searchText, prompt: "Search glossary")
            .navigationTitle("Glossary")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddEntry = true
                        } label: {
                            Label("Add Entry", systemImage: "plus")
                        }
                        
                        Button {
                            showingAnalyzer = true
                        } label: {
                            Label("Analyze Text", systemImage: "sparkles")
                        }
                        
                        Divider()
                        
                        Button {
                            glossaryService.addJapaneseHonorificsPreset()
                        } label: {
                            Label("Add Japanese Honorifics", systemImage: "character.ja")
                        }

                        Button {
                            glossaryService.addJapaneseToEnglishPreset()
                        } label: {
                            Label("Add Japanese → English", systemImage: "text.bubble")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddGlossaryEntrySheet(glossaryService: glossaryService)
            }
            .sheet(isPresented: $showingAnalyzer) {
                TextAnalyzerSheet(glossaryService: glossaryService)
            }
            .sheet(item: $editingEntry) { entry in
                EditGlossaryEntrySheet(glossaryService: glossaryService, entry: entry)
            }
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        Section {
            HStack(spacing: 20) {
                StatBadge(
                    value: "\(glossaryService.totalEntries)",
                    label: "Total",
                    color: .indigo
                )
                
                StatBadge(
                    value: "\(glossaryService.enabledEntries)",
                    label: "Active",
                    color: .green
                )
                
                StatBadge(
                    value: "\(glossaryService.entriesByCategory[.name] ?? 0)",
                    label: "Names",
                    color: .blue
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Category Filter
    
    private var categoryFilterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryChip(
                        title: "All",
                        icon: "square.grid.2x2",
                        isSelected: selectedCategory == nil,
                        color: .gray
                    ) {
                        selectedCategory = nil
                    }
                    
                    ForEach(GlossaryCategory.allCases, id: \.self) { category in
                        CategoryChip(
                            title: category.rawValue,
                            icon: category.icon,
                            isSelected: selectedCategory == category,
                            color: categoryColor(category)
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    }
    
    // MARK: - Entries Section
    
    private var entriesSection: some View {
        Section("Entries (\(filteredEntries.count))") {
            if filteredEntries.isEmpty {
                ContentUnavailableView(
                    "No Entries",
                    systemImage: "text.book.closed",
                    description: Text("Add custom translations for names, terms, and phrases")
                )
                .padding(.vertical, 20)
            } else {
                ForEach(filteredEntries) { entry in
                    GlossaryEntryRow(entry: entry) {
                        editingEntry = entry
                    } onToggle: {
                        glossaryService.toggleEntry(entry)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            glossaryService.deleteEntry(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            glossaryService.toggleEntry(entry)
                        } label: {
                            Label(
                                entry.isEnabled ? "Disable" : "Enable",
                                systemImage: entry.isEnabled ? "xmark.circle" : "checkmark.circle"
                            )
                        }
                        .tint(entry.isEnabled ? .orange : .green)
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        Section("Quick Actions") {
            Button {
                showingAnalyzer = true
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.pink)
                    Text("Analyze Text for Names & Terms")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            
            Button {
                glossaryService.addJapaneseHonorificsPreset()
            } label: {
                HStack {
                    Image(systemName: "character.ja")
                        .foregroundColor(.orange)
                    Text("Add Japanese Honorifics Preset")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }

            Button {
                glossaryService.addJapaneseToEnglishPreset()
            } label: {
                HStack {
                    Image(systemName: "text.bubble")
                        .foregroundColor(.blue)
                    Text("Add Japanese → English Preset")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func categoryColor(_ category: GlossaryCategory) -> Color {
        switch category.color {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "indigo": return .indigo
        case "pink": return .pink
        default: return .gray
        }
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundColor(isSelected ? .white : color)
            .background(isSelected ? color : color.opacity(0.15))
            .cornerRadius(16)
        }
    }
}

// MARK: - Glossary Entry Row

struct GlossaryEntryRow: View {
    let entry: GlossaryEntry
    let onEdit: () -> Void
    let onToggle: () -> Void

    @State private var isEnabled: Bool

    init(entry: GlossaryEntry, onEdit: @escaping () -> Void, onToggle: @escaping () -> Void) {
        self.entry = entry
        self.onEdit = onEdit
        self.onToggle = onToggle
        self._isEnabled = State(initialValue: entry.isEnabled)
    }

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                // Category icon
                Image(systemName: entry.category.icon)
                    .font(.title3)
                    .foregroundColor(categoryColor)
                    .frame(width: 32)
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.sourceText)
                            .font(.body.bold())
                            .foregroundColor(entry.isEnabled ? .primary : .secondary)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(entry.targetText)
                            .font(.body)
                            .foregroundColor(entry.isEnabled ? .indigo : .secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Text(entry.category.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor.opacity(0.15))
                            .cornerRadius(4)
                        
                        if entry.usageCount > 0 {
                            Text("Used \(entry.usageCount)×")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        if !entry.isEnabled {
                            Text("Disabled")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                // Toggle
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .onChange(of: isEnabled) { _, _ in
                        onToggle()
                    }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var categoryColor: Color {
        switch entry.category.color {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "indigo": return .indigo
        case "pink": return .pink
        default: return .gray
        }
    }
}

// MARK: - Add Entry Sheet

struct AddGlossaryEntrySheet: View {
    let glossaryService: GlossaryService
    @Environment(\.dismiss) var dismiss
    
    @State private var sourceText = ""
    @State private var targetText = ""
    @State private var category: GlossaryCategory = .custom
    @State private var isCaseSensitive = true
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Translation Rule") {
                    TextField("Source text (original)", text: $sourceText)
                    TextField("Target text (translation)", text: $targetText)
                }
                
                Section("Options") {
                    Picker("Category", selection: $category) {
                        ForEach(GlossaryCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    
                    Toggle("Case Sensitive", isOn: $isCaseSensitive)
                }
                
                Section("Notes (Optional)") {
                    TextField("Add notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let entry = GlossaryEntry(
                            sourceText: sourceText,
                            targetText: targetText,
                            isCaseSensitive: isCaseSensitive,
                            category: category,
                            notes: notes.isEmpty ? nil : notes
                        )
                        glossaryService.addEntry(entry)
                        dismiss()
                    }
                    .disabled(sourceText.isEmpty || targetText.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Entry Sheet

struct EditGlossaryEntrySheet: View {
    let glossaryService: GlossaryService
    let entry: GlossaryEntry
    @Environment(\.dismiss) var dismiss
    
    @State private var sourceText: String
    @State private var targetText: String
    @State private var category: GlossaryCategory
    @State private var isCaseSensitive: Bool
    @State private var notes: String
    
    init(glossaryService: GlossaryService, entry: GlossaryEntry) {
        self.glossaryService = glossaryService
        self.entry = entry
        _sourceText = State(initialValue: entry.sourceText)
        _targetText = State(initialValue: entry.targetText)
        _category = State(initialValue: entry.category)
        _isCaseSensitive = State(initialValue: entry.isCaseSensitive)
        _notes = State(initialValue: entry.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Translation Rule") {
                    TextField("Source text", text: $sourceText)
                    TextField("Target text", text: $targetText)
                }
                
                Section("Options") {
                    Picker("Category", selection: $category) {
                        ForEach(GlossaryCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    
                    Toggle("Case Sensitive", isOn: $isCaseSensitive)
                }
                
                Section("Notes") {
                    TextField("Add notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(entry.createdAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Times Used")
                        Spacer()
                        Text("\(entry.usageCount)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        glossaryService.deleteEntry(entry)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Entry")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var updated = entry
                        updated.sourceText = sourceText
                        updated.targetText = targetText
                        updated.category = category
                        updated.isCaseSensitive = isCaseSensitive
                        updated.notes = notes.isEmpty ? nil : notes
                        glossaryService.updateEntry(updated)
                        dismiss()
                    }
                    .disabled(sourceText.isEmpty || targetText.isEmpty)
                }
            }
        }
    }
}

// MARK: - Text Analyzer Sheet

struct TextAnalyzerSheet: View {
    let glossaryService: GlossaryService
    @Environment(\.dismiss) var dismiss
    
    @State private var inputText = ""
    @State private var selectedTerms: Set<UUID> = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Input area
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste text to analyze for names & terms:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $inputText)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    
                    HStack {
                        Button("Paste") {
                            if let text = UIPasteboard.general.string {
                                inputText = text
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button {
                            Task {
                                _ = await glossaryService.analyzeText(inputText)
                            }
                        } label: {
                            HStack {
                                if glossaryService.isAnalyzing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text("Analyze")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(inputText.isEmpty || glossaryService.isAnalyzing)
                    }
                }
                .padding()
                
                Divider()
                
                // Results
                if glossaryService.detectedTerms.isEmpty {
                    ContentUnavailableView(
                        "No Terms Detected",
                        systemImage: "sparkles",
                        description: Text("Paste text above and tap Analyze to detect names and key terms")
                    )
                } else {
                    List {
                        Section("Detected Terms (\(glossaryService.detectedTerms.count))") {
                            ForEach(glossaryService.detectedTerms) { term in
                                DetectedTermRow(
                                    term: term,
                                    isSelected: selectedTerms.contains(term.id)
                                ) {
                                    if selectedTerms.contains(term.id) {
                                        selectedTerms.remove(term.id)
                                    } else {
                                        selectedTerms.insert(term.id)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Add selected button
                if !selectedTerms.isEmpty {
                    VStack {
                        Divider()
                        Button {
                            addSelectedTerms()
                        } label: {
                            Text("Add \(selectedTerms.count) Selected to Glossary")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                }
            }
            .navigationTitle("Analyze Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func addSelectedTerms() {
        for termId in selectedTerms {
            if let term = glossaryService.detectedTerms.first(where: { $0.id == termId }) {
                // Add with source = target for now (user can edit later)
                glossaryService.addEntry(from: term, targetText: term.text)
            }
        }
        selectedTerms.removeAll()
        dismiss()
    }
}

// MARK: - Detected Term Row

struct DetectedTermRow: View {
    let term: DetectedTerm
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .indigo : .secondary)
                
                // Term info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(term.text)
                            .font(.body.bold())
                        
                        Text(term.category.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor.opacity(0.15))
                            .foregroundColor(categoryColor)
                            .cornerRadius(4)
                    }
                    
                    Text(term.context)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
    
    private var categoryColor: Color {
        switch term.category {
        case .personalName: return .blue
        case .placeName: return .green
        case .organizationName: return .purple
        case .unknown: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    GlossaryView()
        .environment(AppState())
}
