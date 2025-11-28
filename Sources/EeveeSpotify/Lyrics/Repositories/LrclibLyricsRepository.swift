import Foundation

class LrclibLyricsRepository: LyricsRepository {
    var apiUrl: String
    private let session: URLSession

    private init(apiUrl: String) {
        self.apiUrl = apiUrl
        
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = [
            "User-Agent": "EeveeSpotify v\(EeveeSpotify.version) https://github.com/whoeevee/EeveeSpotify"
        ]
        
        session = URLSession(configuration: configuration)
    }
    
    static let originalApiUrl = "https://lrclib.net/api"
    
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
    
    // 解析 LRC 格式歌词
    private func parseLrcLyrics(_ lrcContent: String) -> [LyricsLineDto] {
        var lines: [LyricsLineDto] = []
        let pattern = "\\[(\\d+):(\\d+)\\.(\\d+)\\](.*)"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let nsString = lrcContent as NSString
            let matches = regex.matches(in: lrcContent, range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                let minuteRange = match.range(at: 1)
                let secondRange = match.range(at: 2)
                let millisecondRange = match.range(at: 3)
                let textRange = match.range(at: 4)
                
                let minute = Int(nsString.substring(with: minuteRange)) ?? 0
                let second = Int(nsString.substring(with: secondRange)) ?? 0
                let millisecond = Int(nsString.substring(with: millisecondRange)) ?? 0
                let words = nsString.substring(with: textRange).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 跳过元数据行（包含标签的行）
                if words.hasPrefix("[") && words.contains("]") {
                    continue
                }
                
                let totalMs = (minute * 60 + second) * 1000 + millisecond * 10
                
                lines.append(LyricsLineDto(
                    words: words,
                    startTimeMs: Int64(totalMs)
                ))
            }
            
            // 按时间排序
            lines.sort { ($0.startTimeMs ?? 0) < ($1.startTimeMs ?? 0) }
            
        } catch {
            print("LRC parsing error: \(error)")
        }
        
        return lines
    }
    
    // 解析逐字歌词格式 (YRC)
    private func parseYrcLyrics(_ yrcContent: String) -> [LyricsLineDto] {
        var lines: [LyricsLineDto] = []
        let linePattern = "\\[(\\d+),(\\d+)\\](.*)"
        
        do {
            let lineRegex = try NSRegularExpression(pattern: linePattern)
            let nsString = yrcContent as NSString
            let lineMatches = lineRegex.matches(in: yrcContent, range: NSRange(location: 0, length: nsString.length))
            
            for lineMatch in lineMatches {
                let lineStartRange = lineMatch.range(at: 1)
                let lineContentRange = lineMatch.range(at: 3)
                
                let lineStartMs = Int64(nsString.substring(with: lineStartRange)) ?? 0
                let lineContent = nsString.substring(with: lineContentRange)
                
                // 提取整行文本（去除时间戳）
                let wordsPattern = "\\((\\d+),(\\d+)\\)([^()]+)"
                let wordsRegex = try NSRegularExpression(pattern: wordsPattern)
                let wordMatches = wordsRegex.matches(in: lineContent, range: NSRange(location: 0, length: lineContent.count))
                
                var lineWords = ""
                for (index, match) in wordMatches.enumerated() {
                    let textRange = match.range(at: 3)
                    let word = nsString.substring(with: textRange)
                    lineWords += word
                    if index < wordMatches.count - 1 {
                        lineWords += " "
                    }
                }
                
                lines.append(LyricsLineDto(
                    words: lineWords.trimmingCharacters(in: .whitespacesAndNewlines),
                    startTimeMs: lineStartMs
                ))
            }
            
            // 按时间排序
            lines.sort { ($0.startTimeMs ?? 0) < ($1.startTimeMs ?? 0) }
            
        } catch {
            print("YRC line parsing error: \(error)")
        }
        
        return lines
    }
    
    // 解析纯文本歌词
    private func parsePlainLyrics(_ plainLyrics: String) -> [LyricsLineDto] {
        return plainLyrics
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { LyricsLineDto(words: $0) }
    }
    
    // 对齐翻译歌词和原歌词
    private func alignTranslations(originalLines: [LyricsLineDto], translationLines: [LyricsLineDto]) -> [String] {
        var alignedTranslations: [String] = Array(repeating: "", count: originalLines.count)
        
        for translation in translationLines {
            // 找到时间戳最接近的原歌词行
            var closestIndex = -1
            var minTimeDiff = Int.max
            
            for (index, originalLine) in originalLines.enumerated() {
                guard let originalStartTimeMs = originalLine.startTimeMs,
                      let translationStartTimeMs = translation.startTimeMs else { continue }
                
                let timeDiff = abs(Int(originalStartTimeMs) - Int(translationStartTimeMs))
                if timeDiff < minTimeDiff {
                    minTimeDiff = timeDiff
                    closestIndex = index
                }
            }
            
            // 如果时间差在合理范围内（比如2秒内），就认为是匹配的
            if closestIndex >= 0 && minTimeDiff <= 2000 && closestIndex < alignedTranslations.count {
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
                romanization: .original
            )
        }

        var lyricsLines: [LyricsLineDto] = []
        var timeSynced = false
        var translation: LyricsTranslationDto? = nil
        var yrcLyrics: String? = nil
        
        // 优先使用逐字歌词 (yrcLyrics)
        if let yrcLyricsContent = song.yrcLyrics, !yrcLyricsContent.isEmpty {
            lyricsLines = parseYrcLyrics(yrcLyricsContent)
            timeSynced = true
            yrcLyrics = yrcLyricsContent
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
        } else {
            throw LyricsError.noSuchSong
        }
        
        // 处理翻译歌词
        if let translatedLyrics = song.translatedLyrics, !translatedLyrics.isEmpty {
            let translationLines = parseLrcLyrics(translatedLyrics)
            let alignedTranslations = alignTranslations(
                originalLines: lyricsLines,
                translationLines: translationLines
            )
            
            translation = LyricsTranslationDto(
                languageCode: "zh",
                lines: alignedTranslations
            )
        }
        
        // 处理罗马化歌词
        var romanization = LyricsRomanizationStatus.original
        
        // 简单判断：如果有中文歌词，则认为可以罗马化
        let hasChinese = lyricsLines.contains { line in
            line.words.range(of: "[\\u4e00-\\u9fff]", options: .regularExpression) != nil
        }
        romanization = hasChinese ? .canBeRomanized : .original
        
        return LyricsDto(
            lines: lyricsLines,
            timeSynced: timeSynced,
            romanization: romanization,
            translation: translation,
            yrcLyrics: yrcLyrics
        )
    }
}
