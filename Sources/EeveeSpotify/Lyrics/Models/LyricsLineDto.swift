// LyricsLineDto.swift
import Foundation

struct LyricsLineDto {
    var words: String
    var startTimeMs: Int64?
    
    // 主构造函数 - 用于新代码
    init(words: String, startTimeMs: Int64? = nil) {
        self.words = words
        self.startTimeMs = startTimeMs
    }
    
    // 兼容构造函数 - 用于旧代码
    init(content: String, offsetMs: Int? = nil) {
        self.words = content
        self.startTimeMs = offsetMs != nil ? Int64(offsetMs!) : nil
    }
}

// 提供兼容性访问器
extension LyricsLineDto {
    var content: String {
        get { words }
        set { words = newValue }
    }
    
    var offsetMs: Int? {
        get { startTimeMs != nil ? Int(startTimeMs!) : nil }
        set { startTimeMs = newValue != nil ? Int64(newValue!) : nil }
    }
}
