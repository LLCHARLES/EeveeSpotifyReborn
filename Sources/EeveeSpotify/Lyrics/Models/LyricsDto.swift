// LyricsDto.swift
import Foundation

struct LyricsDto {
    var lines: [LyricsLineDto]
    var timeSynced: Bool
    var romanization: LyricsRomanizationStatus
    var translation: LyricsTranslationDto?
    var yrcLyrics: String? // 逐字歌词
    
    func toSpotifyLyricsData(source: String) -> ColorLyricsResponse {
        var lyricsResponse = LyricsResponse()
        lyricsResponse.syncType = determineSyncType()
        lyricsResponse.provider = "\(source) (EeveeSpotify)"
        lyricsResponse.providerDisplayName = source
        lyricsResponse.language = "en"
        
        let shouldRomanize = UserDefaults.lyricsOptions.romanization
        
        if lines.isEmpty {
            // 无歌词情况
            let emptyLine = LyricsLine.with {
                $0.words = "song_is_instrumental".localized
                $0.startTimeMs = 0
            }
            lyricsResponse.lines = [emptyLine]
        } else {
            // 有歌词情况
            let sortedLines = lines.sorted { 
                ($0.offsetMs ?? 0) < ($1.offsetMs ?? 0)
            }
            
            lyricsResponse.lines = sortedLines.map { line in
                var lyricsLine = LyricsLine()
                lyricsLine.words = (shouldRomanize && romanization == .canBeRomanized)
                    ? line.content.applyingTransform(.toLatin, reverse: false)!
                    : line.content
                lyricsLine.startTimeMs = Int64(line.offsetMs ?? 0)
                
                // 处理逐字歌词
                if let yrcContent = yrcLyrics {
                    lyricsLine.syllables = parseYrcSyllables(for: line, yrcContent: yrcContent)
                }
                
                return lyricsLine
            }
        }
        
        // 处理翻译
        if let translation = translation {
            var alternative = AlternativeLanguages()
            alternative.language = translation.languageCode
            alternative.lines = translation.lines
            lyricsResponse.alternatives = [alternative]
        }
        
        // 构建完整响应
        var colorLyricsResponse = ColorLyricsResponse()
        colorLyricsResponse.lyrics = lyricsResponse
        colorLyricsResponse.colors = getDefaultColors()
        
        return colorLyricsResponse
    }
    
    private func determineSyncType() -> SyncTypeEnum {
        if yrcLyrics != nil {
            return .syllableSynced
        } else if timeSynced {
            return .lineSynced
        } else {
            return .unsynced
        }
    }
    
    private func parseYrcSyllables(for line: LyricsLineDto, yrcContent: String) -> [Syllable] {
        var syllables: [Syllable] = []
        let pattern = "\\((\\d+),(\\d+)\\)([^()]+)"
        
        guard let lineOffsetMs = line.offsetMs else { return syllables }
        
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let nsString = yrcContent as NSString
            let matches = regex.matches(in: yrcContent, range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                let startRange = match.range(at: 1)
                let durationRange = match.range(at: 2)
                let textRange = match.range(at: 3)
                
                let startMs = Int(nsString.substring(with: startRange)) ?? 0
                let text = nsString.substring(with: textRange)
                
                var syllable = Syllable()
                syllable.startTimeMs = Int64(startMs)
                syllable.numChars = Int64(text.count)
                
                syllables.append(syllable)
            }
        } catch {
            print("YRC parsing error: \(error)")
        }
        
        return syllables
    }
    
    private func getDefaultColors() -> ColorData {
        var colorData = ColorData()
        colorData.background = 0xFF000000  // 黑色背景
        colorData.text = 0xFFFFFFFF        // 白色文字
        colorData.highlightText = 0xFFFFFF00 // 黄色高亮
        return colorData
    }
}

// 为 SwiftProtobuf 结构添加便捷构造器
extension LyricsLine {
    static func with(_ block: (inout LyricsLine) -> Void) -> LyricsLine {
        var message = LyricsLine()
        block(&message)
        return message
    }
}

extension Syllable {
    static func with(_ block: (inout Syllable) -> Void) -> Syllable {
        var message = Syllable()
        block(&message)
        return message
    }
}
