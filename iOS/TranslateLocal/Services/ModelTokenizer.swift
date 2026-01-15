//
//  ModelTokenizer.swift
//  TranslateLocal
//
//  Loads and manages vocabulary and tokenization for Opus-MT and Gemma models
//

import Foundation

class ModelTokenizer {
    private let vocab: [String: Int]
    private let reverseVocab: [Int: String]
    public let config: TokenizerConfig
    private let unkTokenId: Int?
    private let maxPieceChars: Int
    
    public struct TokenizerConfig: Codable {
        let model_name: String
        let vocab_size: Int
        let pad_token_id: Int
        let eos_token_id: Int
        let decoder_start_token_id: Int
        let max_length: Int
    }
    
    init(directory: URL) throws {
        let configURL = directory.appendingPathComponent("config.json")
        let vocabURL = directory.appendingPathComponent("vocab.json")
        
        let configData = try Data(contentsOf: configURL)
        self.config = try JSONDecoder().decode(TokenizerConfig.self, from: configData)
        
        let vocabData = try Data(contentsOf: vocabURL)
        self.vocab = try JSONSerialization.jsonObject(with: vocabData) as? [String: Int] ?? [:]
        
        var reverse: [Int: String] = [:]
        for (key, value) in vocab {
            reverse[value] = key
        }
        self.reverseVocab = reverse
        
        // Try to discover an UNK token id (Marian/SentencePiece commonly uses "<unk>")
        self.unkTokenId = vocab["<unk>"] ?? vocab["<UNK>"] ?? vocab["[UNK]"]
        
        // Precompute a reasonable max piece length for greedy matching (keeps tokenization fast)
        // Ignore obviously-long special tokens by capping at 64 chars.
        let computedMax = vocab.keys.reduce(1) { partial, key in
            max(partial, min(64, key.count))
        }
        self.maxPieceChars = computedMax
    }
    
    func tokenize(_ text: String) -> [Int32] {
        // Opus-MT / MarianTokenizer uses SentencePiece (▁ = word boundary).
        // We implement a lightweight greedy longest-match tokenizer against the saved vocab.
        // This is not a full SentencePiece unigram implementation, but it is vastly better than
        // character-only tokenization and prevents silent empty outputs.
        
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !normalized.isEmpty else { return [] }
        
        var tokens: [Int32] = []
        
        // Split on whitespace; SentencePiece represents spaces via the "▁" prefix on pieces.
        let words = normalized.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        
        for word in words {
            var idx = word.startIndex
            var isFirstPiece = true
            
            while idx < word.endIndex {
                let remaining = word.distance(from: idx, to: word.endIndex)
                let tryLen = min(maxPieceChars, remaining)
                
                var matchedTokenId: Int?
                var matchedLen: Int = 0
                
                // Greedy longest-match.
                for len in stride(from: tryLen, through: 1, by: -1) {
                    let end = word.index(idx, offsetBy: len)
                    let base = String(word[idx..<end])
                    
                    if isFirstPiece, let id = vocab["▁" + base] {
                        matchedTokenId = id
                        matchedLen = len
                        break
                    }
                    
                    if let id = vocab[base] {
                        matchedTokenId = id
                        matchedLen = len
                        break
                    }
                }
                
                if let id = matchedTokenId, matchedLen > 0 {
                    tokens.append(Int32(id))
                    idx = word.index(idx, offsetBy: matchedLen)
                    isFirstPiece = false
                    continue
                }
                
                // Fallback: single character (with optional ▁ prefix at word-start)
                let next = word.index(after: idx)
                let char = String(word[idx..<next])
                
                if isFirstPiece, let id = vocab["▁" + char] {
                    tokens.append(Int32(id))
                } else if let id = vocab[char] {
                    tokens.append(Int32(id))
                } else if let unk = unkTokenId {
                    tokens.append(Int32(unk))
                    DebugLogger.translation("Falling back to <unk> for char '\(char)'", level: .debug)
                } else {
                    DebugLogger.translation("Dropping unknown char '\(char)' (no <unk> in vocab)", level: .warning)
                }
                
                idx = next
                isFirstPiece = false
            }
        }
        
        // Marian models typically expect EOS at end of source sequence.
        tokens.append(Int32(config.eos_token_id))
        
        // Enforce max length (avoid CoreML shape blowups)
        if tokens.count > config.max_length {
            tokens = Array(tokens.prefix(config.max_length))
        }
        
        if tokens.isEmpty {
            DebugLogger.translation("Tokenization produced empty result for: '\(text)'", level: .error)
        } else {
            DebugLogger.translation("Tokenized \(text.count) chars -> \(tokens.count) tokens (maxPieceChars=\(maxPieceChars))", level: .debug)
        }
        
        return tokens
    }
    
    func detokenize(_ tokens: [Int32]) -> String {
        var result = ""
        var decodedCount = 0
        
        for token in tokens {
            let tokenId = Int(token)
            if tokenId == config.eos_token_id { break }
            if tokenId == config.pad_token_id { continue }
            if tokenId == config.decoder_start_token_id { continue }
            
            if let word = reverseVocab[tokenId] {
                // Handle SentencePiece markers (▁ means word start/space)
                var cleanWord = word
                    .replacingOccurrences(of: "▁", with: " ")   // SentencePiece word boundary
                    .replacingOccurrences(of: "##", with: "")    // BERT-style continuation
                result += cleanWord
                decodedCount += 1
            }
        }
        
        let finalResult = result.trimmingCharacters(in: .whitespaces)
        DebugLogger.translation("Detokenized \(tokens.count) tokens -> \(decodedCount) words: '\(finalResult.prefix(50))...'", level: .debug)
        return finalResult
    }
}
