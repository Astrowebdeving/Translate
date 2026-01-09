//
//  HistoryView.swift
//  TranslateLocal
//
//  Translation history management
//

import SwiftUI

// MARK: - History Item Model

struct TranslationHistoryItem: Identifiable, Codable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let timestamp: Date
    var isFavorite: Bool
    
    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String,
        timestamp: Date = Date(),
        isFavorite: Bool = false
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = timestamp
        self.isFavorite = isFavorite
    }
}

// MARK: - History Manager

@MainActor
class HistoryManager: ObservableObject {
    @Published var items: [TranslationHistoryItem] = []
    
    private let maxItems = 500
    private let storageKey = "translationHistory"
    
    init() {
        loadHistory()
    }
    
    func addItem(_ item: TranslationHistoryItem) {
        items.insert(item, at: 0)
        
        // Limit history size
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        
        saveHistory()
    }
    
    func toggleFavorite(_ item: TranslationHistoryItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isFavorite.toggle()
            saveHistory()
        }
    }
    
    func deleteItem(_ item: TranslationHistoryItem) {
        items.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        saveHistory()
    }
    
    func clearAll() {
        items.removeAll()
        saveHistory()
    }
    
    var favorites: [TranslationHistoryItem] {
        items.filter { $0.isFavorite }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TranslationHistoryItem].self, from: data) else {
            return
        }
        items = decoded
    }
    
    private func saveHistory() {
        guard let encoded = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }
}

// MARK: - History View

struct HistoryView: View {
    @StateObject private var historyManager = HistoryManager()
    @State private var searchText = ""
    @State private var showFavoritesOnly = false
    @State private var selectedItem: TranslationHistoryItem?
    
    var filteredItems: [TranslationHistoryItem] {
        var items = showFavoritesOnly ? historyManager.favorites : historyManager.items
        
        if !searchText.isEmpty {
            items = items.filter {
                $0.sourceText.localizedCaseInsensitiveContains(searchText) ||
                $0.translatedText.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return items
    }
    
    var groupedItems: [(String, [TranslationHistoryItem])] {
        let grouped = Dictionary(grouping: filteredItems) { item in
            dateGroupKey(for: item.timestamp)
        }
        
        return grouped.sorted { $0.key > $1.key }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if historyManager.items.isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search translations")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Toggle(isOn: $showFavoritesOnly) {
                            Label("Favorites Only", systemImage: "star.fill")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            historyManager.clearAll()
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $selectedItem) { item in
                HistoryDetailSheet(item: item, historyManager: historyManager)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.secondary)
            
            Text("No History Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your translation history will appear here")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private var listView: some View {
        List {
            ForEach(groupedItems, id: \.0) { group in
                Section(header: Text(group.0)) {
                    ForEach(group.1) { item in
                        HistoryItemRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedItem = item
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    historyManager.deleteItem(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    historyManager.toggleFavorite(item)
                                } label: {
                                    Label(
                                        item.isFavorite ? "Unfavorite" : "Favorite",
                                        systemImage: item.isFavorite ? "star.slash" : "star.fill"
                                    )
                                }
                                .tint(.yellow)
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func dateGroupKey(for date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            return "This Week"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .month) {
            return "This Month"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - History Item Row

struct HistoryItemRow: View {
    let item: TranslationHistoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(item.sourceLanguage.uppercased()) → \(item.targetLanguage.uppercased())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                
                Text(item.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(item.sourceText)
                .font(.subheadline)
                .lineLimit(2)
            
            Text(item.translatedText)
                .font(.subheadline)
                .foregroundColor(.indigo)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - History Detail Sheet

struct HistoryDetailSheet: View {
    let item: TranslationHistoryItem
    let historyManager: HistoryManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Languages
                    HStack {
                        LanguageBadge(code: item.sourceLanguage)
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                        LanguageBadge(code: item.targetLanguage)
                        Spacer()
                    }
                    
                    // Source text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Original")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(item.sourceText)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Translated text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Translation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(item.translatedText)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.indigo.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Actions
                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = item.translatedText
                        } label: {
                            Label("Copy Translation", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            historyManager.toggleFavorite(item)
                        } label: {
                            Label(
                                item.isFavorite ? "Unfavorite" : "Favorite",
                                systemImage: item.isFavorite ? "star.fill" : "star"
                            )
                        }
                        .buttonStyle(.bordered)
                        .tint(.yellow)
                    }
                    
                    // Timestamp
                    Text("Translated on \(item.timestamp.formatted(date: .long, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Translation Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LanguageBadge: View {
    let code: String
    
    var body: some View {
        Text(code.uppercased())
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(6)
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
}
