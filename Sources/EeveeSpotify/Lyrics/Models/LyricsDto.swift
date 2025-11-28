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
            lyricsResponse.lines = [createEmptyLine()]
        } else {
            // 有歌词情况
            let sortedLines = lines.sorted { 
                ($0.startTimeMs ?? 0) < ($1.startTimeMs ?? 0)
            }
            
            lyricsResponse.lines = sortedLines.map { line in
                createLyricsLine(from: line, shouldRomanize: shouldRomanize)
            }
        }
        
        // 处理翻译
        if let translation = translation {
            lyricsResponse.alternatives = [createAlternativeLanguage(from: translation)]
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
    
    private func createEmptyLine() -> LyricsLine {
        var lyricsLine = LyricsLine()
        lyricsLine.words = "song_is_instrumental".localized
        lyricsLine.startTimeMs = 0
        return lyricsLine
    }
    
    private func createLyricsLine(from dto: LyricsLineDto, shouldRomanize: Bool) -> LyricsLine {
        var lyricsLine = LyricsLine()
        
        // 直接使用 words 字段
        lyricsLine.words = shouldRomanize && romanization == .canBeRomanized
            ? dto.words.applyingTransform(.toLatin, reverse: false)!
            : dto.words
            
        lyricsLine.startTimeMs = dto.startTimeMs ?? 0
        
        // 处理逐字歌词
        if let yrcContent = yrcLyrics {
            lyricsLine.syllables = parseYrcSyllables(for: dto, yrcContent: yrcContent)
        }
        
        return lyricsLine
    }
    
    private func parseYrcSyllables(for line: LyricsLineDto, yrcContent: String) -> [Syllable] {
        var syllables: [Syllable] = []
        let pattern = "\\((\\d+),(\\d+)\\)([^()]+)"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let nsString = yrcContent as NSString
            let matches = regex.matches(in: yrcContent, range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                let startRange = match.range(at: 1)
                let textRange = match.range(at: 3)
                
                let startMs = Int64(nsString.substring(with: startRange)) ?? 0
                let words = nsString.substring(with: textRange)
                
                var syllable = Syllable()
                syllable.startTimeMs = startMs
                syllable.numChars = Int64(words.count)
                
                syllables.append(syllable)
            }
        } catch {
            print("YRC parsing error: \(error)")
        }
        
        return syllables
    }
    
    private func createAlternativeLanguage(from translation: LyricsTranslationDto) -> AlternativeLanguages {
        var alternative = AlternativeLanguages()
        alternative.language = translation.languageCode
        alternative.lines = translation.lines
        return alternative
    }
    
    private func getDefaultColors() -> ColorData {
        var colorData = ColorData()
        colorData.background = 0xFF000000  // 黑色背景
        colorData.text = 0xFFFFFFFF        // 白色文字
        colorData.highlightText = 0xFFFFFF00 // 黄色高亮
        return colorData
    }
}
