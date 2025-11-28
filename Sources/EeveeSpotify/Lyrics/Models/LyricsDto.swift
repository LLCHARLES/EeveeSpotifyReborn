// LyricsDto.swift
import Foundation

struct LyricsDto {
    var lines: [LyricsLineDto]
    var timeSynced: Bool
    var romanization: LyricsRomanizationStatus
    var translation: LyricsTranslationDto?
    var yrcLyrics: String? // 逐字歌词
    
    func toSpotifyLyricsData(source: String) -> ColorLyricsResponse {
        var lyricsResponse = LyricsResponse.with {
            $0.syncType = determineSyncType()
            $0.provider = "\(source) (EeveeSpotify)"
            $0.providerDisplayName = source
            $0.language = "en"
        }
        
        let shouldRomanize = UserDefaults.lyricsOptions.romanization
        
        if lines.isEmpty {
            // 无歌词情况
            lyricsResponse.lines = [
                LyricsLine.with {
                    $0.words = "song_is_instrumental".localized
                    $0.startTimeMs = 0
                }
            ]
        } else {
            // 有歌词情况
            let sortedLines = lines.sorted { 
                ($0.offsetMs ?? 0) < ($1.offsetMs ?? 0)
            }
            
            lyricsResponse.lines = sortedLines.map { line in
                var lyricsLine = LyricsLine.with {
                    $0.words = (shouldRomanize && romanization == .canBeRomanized)
                        ? line.content.applyingTransform(.toLatin, reverse: false)!
                        : line.content
                    $0.startTimeMs = Int64(line.offsetMs ?? 0)
                }
                
                // 处理逐字歌词
                if let yrcContent = yrcLyrics {
                    lyricsLine.syllables = parseYrcSyllables(for: line, yrcContent: yrcContent)
                }
                
                return lyricsLine
            }
        }
        
        // 处理翻译
        if let translation = translation {
            let alternative = AlternativeLanguages.with {
                $0.language = translation.languageCode
                $0.lines = translation.lines
            }
            lyricsResponse.alternatives = [alternative]
        }
        
        // 构建完整响应
        return ColorLyricsResponse.with {
            $0.lyrics = lyricsResponse
            $0.colors = getDefaultColors()
        }
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
                
                let syllable = Syllable.with {
                    $0.startTimeMs = Int64(startMs)
                    $0.numChars = Int64(text.count)
                }
                
                syllables.append(syllable)
            }
        } catch {
            print("YRC parsing error: \(error)")
        }
        
        return syllables
    }
    
    private func getDefaultColors() -> ColorData {
        return ColorData.with {
            $0.background = 0xFF000000  // 黑色背景
            $0.text = 0xFFFFFFFF        // 白色文字
            $0.highlightText = 0xFFFFFF00 // 黄色高亮
        }
    }
}
