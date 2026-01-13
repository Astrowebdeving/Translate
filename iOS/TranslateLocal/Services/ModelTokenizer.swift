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
    private let config: TokenizerConfig
    
    struct TokenizerConfig: Codable {
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
    }
    
    func tokenize(_ text: String) -> [Int32] {
        // Simplified BPE/Wordpiece-like tokenization
        // In a real app, you'd want a more robust SentencePiece implementation
        // But this works for basic vocabulary matching
        let words = text.lowercased().split(separator: " ")
        var tokens: [Int32] = []
        
        for word in words {
            let wordStr = String(word)
            if let token = vocab[wordStr] {
                tokens.append(Int32(token))
            } else {
                // Fallback to character-level or UNK
                for char in wordStr {
                    if let charToken = vocab[String(char)] {
                        tokens.append(Int32(charToken))
                    }
                }
            }
        }
        
        return tokens
    }
    
    func detokenize(_ tokens: [Int32]) -> String {
        var result = ""
        for token in tokens {
            let tokenId = Int(token)
            if tokenId == config.eos_token_id { break }
            if tokenId == config.pad_token_id { continue }
            
            if let word = reverseVocab[tokenId] {
                // Remove BPE artifacts (like ' ', '##', etc. depending on model)
                let cleanWord = word.replacingOccurrences(of: " ", with: " ")
                                    .replacingOccurrences(of: "##", with: "")
                result += cleanWord
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}
