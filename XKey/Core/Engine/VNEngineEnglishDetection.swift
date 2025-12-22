//
//  VNEngineEnglishDetection.swift
//  XKey
//
//  English word detection for spell checking optimization
//  Helps skip Vietnamese processing for definitely English words
//

import Foundation

extension String {
    
    /// Ultra-fast English detection for real-time typing
    /// Returns true if word is DEFINITELY English (high confidence)
    /// Used to skip Vietnamese spell checking and processing
    var isDefinitelyEnglish: Bool {
        let word = self.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Empty or too short to determine
        if word.count < 2 {
            return false
        }
        
        // 1. Contains f, j, w, z → almost certainly not pure Vietnamese
        //    Note: Some Vietnamese words use these with vAllowConsonantZFWJ,
        //    but they're rare and mostly loan words
        if word.rangeOfCharacter(from: CharacterSet(charactersIn: "fjwz")) != nil {
            return true
        }
        
        // 2. Ends with 's' → likely English plural
        //    Vietnamese words never end with 's'
        if word.hasSuffix("s") && word.count > 2 {
            return true
        }
        
        // 3. Contains 3+ consecutive consonants → very rare in Vietnamese
        //    Examples: "street", "strength", "scratch"
        //    BUT we need to exclude valid Vietnamese consonant clusters first:
        //    - "ngh" (nghi, nghĩ, nghỉ, nghiêm...)
        //    - "ngr" (if vAllowConsonantZFWJ enabled)
        //    - Other Vietnamese clusters: tr, ch, th, nh, ng, kh, ph, gi, qu
        let wordForConsonantCheck = word
            .replacingOccurrences(of: "ngh", with: "_")  // ngh → single placeholder
            .replacingOccurrences(of: "ng", with: "_")   // ng → single placeholder
            .replacingOccurrences(of: "nh", with: "_")   // nh → single placeholder
            .replacingOccurrences(of: "ch", with: "_")   // ch → single placeholder
            .replacingOccurrences(of: "th", with: "_")   // th → single placeholder
            .replacingOccurrences(of: "kh", with: "_")   // kh → single placeholder
            .replacingOccurrences(of: "ph", with: "_")   // ph → single placeholder
            .replacingOccurrences(of: "tr", with: "_")   // tr → single placeholder
            .replacingOccurrences(of: "gi", with: "_")   // gi → single placeholder
            .replacingOccurrences(of: "qu", with: "_")   // qu → single placeholder
        
        if wordForConsonantCheck.range(of: "[bcdfghjklmnpqrstvwxyz]{3,}", 
                      options: .regularExpression) != nil {
            return true
        }
        
        // 4. English initial clusters not found in Vietnamese
        //    Examples: "str", "spr", "scr", "thr", "shr"
        let englishClusters = ["str", "spr", "scr", "spl", "shr", "thr", "sch"]
        for cluster in englishClusters {
            if word.hasPrefix(cluster) {
                return true
            }
        }
        
        // 5. Silent letter patterns characteristic of English
        //    Examples: "know", "write", "psychology", "lamb"
        let silentPatterns = ["^kn", "^wr", "^ps", "mb$", "lm$"]
        for pattern in silentPatterns {
            if word.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        // 6. Ends with consonants invalid in Vietnamese
        //    Vietnamese only allows: c, ch, m, n, ng, nh, p, t
        if let last = word.last {
            let invalidEndings = CharacterSet(charactersIn: "bdlrvfz")
            if String(last).rangeOfCharacter(from: invalidEndings) != nil {
                return true
            }
        }
        
        // 7. English vowel combinations not found in Vietnamese
        //    Examples: "though", "weight", "book", "feet"
        //    Only check if word is long enough to avoid false positives
        if word.count > 3 {
            let englishVowelCombos = ["ough", "eigh", "oo", "ee"]
            for combo in englishVowelCombos {
                if word.contains(combo) {
                    return true
                }
            }
        }
        
        return false
    }
}

extension VNEngine {
    
    /// Get current typing word as a String for analysis
    /// Converts internal buffer to readable text
    func getCurrentWordString() -> String {
        guard index > 0 else { return "" }
        
        var result = ""
        for i in 0..<Int(index) {
            let keyCode = UInt16(typingWord[i] & VNEngine.CHAR_MASK)
            
            // Convert keyCode to character
            if let char = keyCodeToCharacter(keyCode) {
                result.append(char)
            }
        }
        
        return result
    }
    
    /// Convert keyCode to character for string building
    private func keyCodeToCharacter(_ keyCode: UInt16) -> Character? {
        // Map common key codes to characters
        let mapping: [UInt16: Character] = [
            0x00: "a", 0x0B: "b", 0x08: "c", 0x02: "d", 0x0E: "e",
            0x03: "f", 0x05: "g", 0x04: "h", 0x22: "i", 0x26: "j",
            0x28: "k", 0x25: "l", 0x2E: "m", 0x2D: "n", 0x1F: "o",
            0x23: "p", 0x0C: "q", 0x0F: "r", 0x01: "s", 0x11: "t",
            0x20: "u", 0x09: "v", 0x0D: "w", 0x07: "x", 0x10: "y",
            0x06: "z"
        ]
        return mapping[keyCode]
    }
    
    /// Check if current buffer is definitely English
    /// Used as early exit optimization in spell checking
    func isCurrentWordDefinitelyEnglish() -> Bool {
        // Only check if we have enough characters to make a determination
        guard index >= 3 else { return false }
        
        let word = getCurrentWordString()
        return word.isDefinitelyEnglish
    }
}
