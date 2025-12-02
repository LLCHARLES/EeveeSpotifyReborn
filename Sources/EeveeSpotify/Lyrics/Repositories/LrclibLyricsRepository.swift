import Foundation

class LrclibLyricsRepository: LyricsRepository {
    var apiUrl: String
    private let session: URLSession
    
    // ✅ 缓存所有正则表达式为静态变量
    private static let lrcRegex = try! NSRegularExpression(pattern: #"\[(\d+):(\d+)\.(\d+)\](.*)"#)
    private static let yrcLineRegex = try! NSRegularExpression(pattern: #"\[(\d+),(\d+)\](.*)"#)
    private static let yrcWordRegex = try! NSRegularExpression(pattern: #"([^\(]*?)\((\d+),(\d+)\)"#)
    private static let specialFormatRegex = try! NSRegularExpression(pattern: #"\(\((\d+),(\d+)\)([^\(\)]+)\)"#)

    private init(apiUrl: String) {
        self.apiUrl = apiUrl
        
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = [
            "User-Agent": "EeveeSpotify v\(EeveeSpotify.version) https://github.com/whoeevee/EeveeSpotify"
        ]
        
        session = URLSession(configuration: configuration)
    }
    
    static let originalApiUrl = "https://qqmusic-lyrics-api.zeabur.app/api"
    
    static let shared = LrclibLyricsRepository(
        apiUrl: UserDefaults.lyricsOptions.lrclibUrl
    )
    
    private func perform(
        _ path: String, 
        query: [String:Any] = [:]
    ) throws -> Data {
        var stringUrl = "\(apiUrl)\(path)"

        if !query.isEmpty {
            let queryString = query.queryString
            stringUrl += "?\(queryString)"
        }
        
        let request = URLRequest(url: URL(string: stringUrl)!)

        let semaphore = DispatchSemaphore(value: 0)
        var data: Data?
        var error: Error?

        let task = session.dataTask(with: request) { response, _, err in
            error = err
            data = response
            semaphore.signal()
        }

        task.resume()
        semaphore.wait()

        if let error = error {
            throw error
        }

        return data!
    }
    
    private func getSong(trackName: String, artistName: String) throws -> LrclibSong {
        let data: Data = try perform("/get", query: [
            "track_name": trackName,
            "artist_name": artistName
        ])
        return try JSONDecoder().decode(LrclibSong.self, from: data)
    }
    
    // ✅ 优化 LRC 格式歌词解析
    private func parseLrcLyrics(_ lrcContent: String) -> [LyricsLineDto] {
        var lines: [LyricsLineDto] = []
        lines.reserveCapacity(50) // 预分配容量
        
        let nsString = lrcContent as NSString
        let matches = Self.lrcRegex.matches(
            in: lrcContent, 
            range: NSRange(location: 0, length: nsString.length)
        )
        
        for match in matches {
            let minute = Int(nsString.substring(with: match.range(at: 1))) ?? 0
            let second = Int(nsString.substring(with: match.range(at: 2))) ?? 0
            let millisecond = Int(nsString.substring(with: match.range(at: 3))) ?? 0
            let text = nsString.substring(with: match.range(at: 4))
            
            let totalMs = (minute * 60 + second) * 1000 + millisecond * 10
            
            lines.append(LyricsLineDto(
                words: text,
                startTimeMs: Int64(totalMs),
                syllables: nil
            ))
        }
        
        // 按时间排序
        lines.sort { ($0.startTimeMs ?? 0) < ($1.startTimeMs ?? 0) }
        
        return lines
    }
    
    // ✅ 优化逐字歌词解析 (YRC格式) - 保留特殊格式处理
    private func parseYrcLyrics(_ yrcContent: String) -> [LyricsLineDto] {
        var lines: [LyricsLineDto] = []
        lines.reserveCapacity(50) // 预分配容量
        
        let lineStrings = yrcContent.components(separatedBy: "\n")
        
        for lineString in lineStrings {
            guard !lineString.isEmpty else { continue }
            
            let nsString = lineString as NSString
            let lineMatches = Self.yrcLineRegex.matches(
                in: lineString, 
                range: NSRange(location: 0, length: nsString.length)
            )
            
            guard let match = lineMatches.first else { continue }
            
            let lineStartMs = Int64(nsString.substring(with: match.range(at: 1))) ?? 0
            let lineContent = nsString.substring(with: match.range(at: 3))
            
            // ✅ 提前检测是否有特殊格式（只检测一次）
            let hasSpecialFormat = Self.specialFormatRegex.firstMatch(
                in: lineContent,
                range: NSRange(location: 0, length: lineContent.count)
            ) != nil
            
            // 使用数组收集，避免字符串频繁拼接
            var wordTexts: [String] = []
            var syllables: [SyllableDto] = []
            
            let wordMatches = Self.yrcWordRegex.matches(
                in: lineContent,
                range: NSRange(location: 0, length: lineContent.count)
            )
            
            let nsLineContent = lineContent as NSString
            
            for wordMatch in wordMatches {
                let wordTextRange = wordMatch.range(at: 1)
                let wordStartMs = Int64(nsLineContent.substring(with: wordMatch.range(at: 2))) ?? 0
                
                if wordTextRange.location != NSNotFound {
                    var wordText = nsLineContent.substring(with: wordTextRange)
                    
                    // ✅ 处理特殊格式：((时间戳)单词) -> (单词)
                    if hasSpecialFormat {
                        let specialMatches = Self.specialFormatRegex.matches(
                            in: lineContent,
                            range: NSRange(location: 0, length: lineContent.count)
                        )
                        
                        for specialMatch in specialMatches {
                            let specialWordRange = specialMatch.range(at: 3)
                            let specialWord = nsLineContent.substring(with: specialWordRange)
                            wordText = "(\(specialWord))"
                            break // 只处理第一个匹配的特殊格式
                        }
                    }
                    
                    wordTexts.append(wordText)
                    
                    syllables.append(SyllableDto(
                        startTimeMs: wordStartMs,
                        numChars: Int64(wordText.count)
                    ))
                }
            }
            
            // 一次性拼接所有文本
            let fullLineText = wordTexts.joined()
            
            lines.append(LyricsLineDto(
                words: fullLineText,
                startTimeMs: lineStartMs,
                syllables: syllables.isEmpty ? nil : syllables
            ))
        }
        
        // 按时间排序
        lines.sort { ($0.startTimeMs ?? 0) < ($1.startTimeMs ?? 0) }
        
        return lines
    }
        
    // 解析纯文本歌词
    private func parsePlainLyrics(_ plainLyrics: String) -> [LyricsLineDto] {
        return plainLyrics
            .components(separatedBy: "\n")
            .map { LyricsLineDto(words: $0, startTimeMs: nil, syllables: nil) }
    }
    
    // ✅ 优化翻译歌词对齐
    private func alignTranslations(originalLines: [LyricsLineDto], translationLines: [LyricsLineDto]) -> [String] {
        var alignedTranslations: [String] = Array(repeating: "", count: originalLines.count)
        
        for translation in translationLines {
            guard let translationStartTimeMs = translation.startTimeMs else { continue }
            
            // 找到时间戳最接近的原歌词行
            var closestIndex = -1
            var minTimeDiff = Int.max
            
            for (index, originalLine) in originalLines.enumerated() {
                guard let originalStartTimeMs = originalLine.startTimeMs else { continue }
                
                let timeDiff = abs(Int(originalStartTimeMs) - Int(translationStartTimeMs))
                if timeDiff < minTimeDiff {
                    minTimeDiff = timeDiff
                    closestIndex = index
                }
            }
            
            if closestIndex >= 0 && closestIndex < alignedTranslations.count {
                alignedTranslations[closestIndex] = translation.words
            }
        }
        
        return alignedTranslations
    }

    func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> LyricsDto {
        let song: LrclibSong

        do {
            song = try getSong(trackName: query.title, artistName: query.primaryArtist)
        } catch {
            let strippedTitle = query.title.strippedTrackTitle
            do {
                song = try getSong(trackName: strippedTitle, artistName: query.primaryArtist)
            } catch {
                throw LyricsError.noSuchSong
            }
        }

        if song.instrumental {
            return LyricsDto(
                lines: [], 
                timeSynced: false, 
                isSyllableSynced: false,
                romanization: .original,
                translation: nil
            )
        }

        var lyricsLines: [LyricsLineDto] = []
        var timeSynced = false
        var isSyllableSynced = false
        var translation: LyricsTranslationDto? = nil
        
        // 优先使用逐字歌词 (yrcLyrics)
        if let yrcLyrics = song.yrcLyrics, !yrcLyrics.isEmpty {
            lyricsLines = parseYrcLyrics(yrcLyrics)
            timeSynced = true
            isSyllableSynced = true
        }
        // 其次使用时间轴歌词 (syncedLyrics)
        else if let syncedLyrics = song.syncedLyrics, !syncedLyrics.isEmpty {
            lyricsLines = parseLrcLyrics(syncedLyrics)
            timeSynced = true
        }
        // 最后使用纯文本歌词 (plainLyrics)
        else if let plainLyrics = song.plainLyrics, !plainLyrics.isEmpty {
            lyricsLines = parsePlainLyrics(plainLyrics)
            timeSynced = false
        }
        
        // 处理翻译歌词 - 使用对齐方法
        if let translatedLyrics = song.translatedLyrics, 
           !translatedLyrics.isEmpty,
           !lyricsLines.isEmpty {
            // 解析翻译歌词
            let translationLines = parseLrcLyrics(translatedLyrics)
            
            // 使用时间戳对齐翻译和原歌词
            let alignedTranslations = alignTranslations(
                originalLines: lyricsLines,
                translationLines: translationLines
            )
            
            translation = LyricsTranslationDto(
                languageCode: "zh",
                lines: alignedTranslations
            )
        }
        
        // ✅ 优化中文检测（使用 CharacterSet 比正则更快）
        let chineseCharacterSet = CharacterSet(charactersIn: "\u{4e00}"..."\u{9fff}")
        let romanization: LyricsRomanizationStatus = lyricsLines.contains(where: { 
            $0.words.rangeOfCharacter(from: chineseCharacterSet) != nil
        }) ? .canBeRomanized : .original
        
        return LyricsDto(
            lines: lyricsLines,
            timeSynced: timeSynced,
            isSyllableSynced: isSyllableSynced,
            romanization: romanization,
            translation: translation
        )
    }
}
