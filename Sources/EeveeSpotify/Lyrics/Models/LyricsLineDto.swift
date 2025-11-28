// LyricsLineDto.swift
import Foundation

struct LyricsLineDto {
    var words: String
    var startTimeMs: Int64?
    
    init(words: String, startTimeMs: Int64? = nil) {
        self.words = words
        self.startTimeMs = startTimeMs
    }
}
