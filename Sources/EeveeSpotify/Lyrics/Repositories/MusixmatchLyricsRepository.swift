import Foundation
import UIKit

class MusixmatchLyricsRepository: LyricsRepository {
    private let apiUrl = "https://charlesl.qzz.io/api/musixmatch"

    var selectedLanguage: String

    static let shared = MusixmatchLyricsRepository(
        language: UserDefaults.lyricsOptions.musixmatchLanguage
    )

    private init(language: String) {
        selectedLanguage = language
    }

    //

    private class CachedLyrics {
        let dto: LyricsDto

        init(dto: LyricsDto) {
            self.dto = dto
        }
    }

    private let lyricsCache = NSCache<NSString, CachedLyrics>()

    private func getCacheKey(for query: LyricsSearchQuery) -> String {
        return "\(query.hashValue)_\(selectedLanguage)"
    }

    //

    private func perform(
        _ path: String,
        query: [String: Any] = [:]
    ) throws -> Data {
        var stringUrl = apiUrl
        
        var finalQuery = query
        finalQuery["target_path"] = path
        finalQuery["usertoken"] = UserDefaults.musixmatchToken
        finalQuery["app_id"] = UIDevice.current.musixmatchAppId

        let queryString = finalQuery.queryString
        stringUrl += "?\(queryString)"

        let request = URLRequest(url: URL(string: stringUrl)!)

        let semaphore = DispatchSemaphore(value: 0)
        var data: Data?
        var error: Error?

        let task = URLSession.shared.dataTask(with: request) { response, _, err in
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

    //

    private func getMacroCalls(_ data: Data) throws -> [String: Any] {
        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
            let message = json["message"] as? [String: Any],
            let body = message["body"] as? [String: Any],
            let macroCalls = body["macro_calls"] as? [String: Any]
        else {
            throw LyricsError.decodingError
        }

        if let header = message["header"] as? [String: Any],
            header["status_code"] as? Int == 401
        {
            throw LyricsError.invalidMusixmatchToken
        }

        return macroCalls
    }

    private func getFirstSubtitle(_ subtitlesMessage: [String: Any]) throws -> [String: Any] {
        guard
            let subtitlesBody = subtitlesMessage["body"] as? [String: Any],
            let subtitleList = subtitlesBody["subtitle_list"] as? [[String: Any]],
            let firstSubtitle = subtitleList.first,
            let subtitle = firstSubtitle["subtitle"] as? [String: Any]
        else {
            throw LyricsError.decodingError
        }

        if let restricted = subtitle["restricted"] as? Bool, restricted {
            throw LyricsError.musixmatchRestricted
        }

        return subtitle
    }

    //

    private func getTranslations(_ spotifyTrackId: String, selectedLanguage: String) throws
        -> [String: String]
    {
        let data = try perform(
            "/ws/1.1/crowd.track.translations.get",
            query: [
                "track_spotify_id": spotifyTrackId,
                "selected_language": selectedLanguage,
            ]
        )

        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
            let message = json["message"] as? [String: Any],
            let body = message["body"] as? [String: Any],
            let translationsList = body["translations_list"] as? [[String: Any]]
        else {
            throw LyricsError.decodingError
        }

        let translations = translationsList.compactMap {
            $0["translation"] as? [String: Any]
        }

        return translations.reduce(into: [:]) { dictionary, translation in
            dictionary[translation["subtitle_matched_line"] as! String] =
                translation["description"] as? String
        }
    }

    // MARK: - RichSync 逐字歌词解析

    private func parseRichSyncLyrics(_ richsyncBody: String) -> [LyricsLineDto] {
        guard let data = richsyncBody.data(using: .utf8) else {
            return []
        }
        
        do {
            let richSyncLines = try JSONDecoder().decode([MusixmatchRichSync].self, from: data)
            
            return richSyncLines.map { richSync in
                let lineStartMs = Int64(richSync.ts * 1000)
                var syllables: [SyllableDto] = []
                var fullText = ""
                
                for word in richSync.l {
                    let wordStartMs = lineStartMs + Int64(word.o * 1000)
                    
                    syllables.append(SyllableDto(
                        startTimeMs: wordStartMs,
                        numChars: Int64(word.c.count)
                    ))
                    fullText += word.c
                }
                
                return LyricsLineDto(
                    words: fullText,
                    startTimeMs: lineStartMs,
                    syllables: syllables
                )
            }
        } catch {
            print("Failed to parse RichSync: \(error)")
            return []
        }
    }

    //

    func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> LyricsDto {
        let cacheKey = getCacheKey(for: query)

        if let cached = lyricsCache.object(forKey: cacheKey as NSString) {
            return cached.dto
        }

        // ========== 第一步：获取 RichSync 逐字歌词 ==========
        var richsyncLines: [LyricsLineDto] = []
        var hasRichSync = false
        var subtitleLanguage: String?
        
        var richsyncQuery: [String: Any] = [
            "track_spotify_id": query.spotifyTrackId,
            "q_track": query.title,
            "q_artist": query.primaryArtist,
            "format": "json"
        ]
        
        if !selectedLanguage.isEmpty && selectedLanguage != "en" {
            richsyncQuery["selected_language"] = selectedLanguage
        }
        
        do {
            let data = try perform(
                "/ws/1.1/track.richsync.get",
                query: richsyncQuery
            )
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? [String: Any],
               let header = message["header"] as? [String: Any],
               let statusCode = header["status_code"] as? Int,
               statusCode == 200,
               let body = message["body"] as? [String: Any],
               let richsync = body["richsync"] as? [String: Any],
               let richsyncBodyString = richsync["richsync_body"] as? String {
                
                richsyncLines = parseRichSyncLyrics(richsyncBodyString)
                if !richsyncLines.isEmpty {
                    hasRichSync = true
                    subtitleLanguage = richsync["richssync_language"] as? String
                }
            }
        } catch {
            print("RichSync request failed: \(error)")
        }

        // ========== 第二步：获取字幕（包含翻译数据） ==========
        var musixmatchQuery: [String: Any] = [
            "track_spotify_id": query.spotifyTrackId,
            "subtitle_format": "mxm",
            "q_track": query.title,
            "q_artist": query.primaryArtist,
        ]

        if !selectedLanguage.isEmpty {
            musixmatchQuery["selected_language"] = selectedLanguage
            musixmatchQuery["part"] = "subtitle_translated"
        }

        let data = try perform(
            "/ws/1.1/macro.subtitles.get",
            query: musixmatchQuery
        )

        var romanized = false
        var translation: LyricsTranslationDto? = nil
        var subtitleLines: [LyricsLineDto] = []

        let macroCalls = try getMacroCalls(data)

        if let trackSubtitlesGet = macroCalls["track.subtitles.get"] as? [String: Any],
            let subtitlesMessage = trackSubtitlesGet["message"] as? [String: Any],
            let subtitle = try? getFirstSubtitle(subtitlesMessage),
            let subLanguage = subtitle["subtitle_language"] as? String,
            let subtitleBody = subtitle["subtitle_body"] as? String,
            let subtitles = try? JSONDecoder().decode(
                [MusixmatchSubtitle].self, from: subtitleBody.data(using: .utf8)!
            )
        {
            // 如果没有从 RichSync 获取到语言，使用字幕的语言
            if subtitleLanguage == nil {
                subtitleLanguage = subLanguage
            }
            
            let romanizationLanguage = "r\(subLanguage.prefix(1))"

            subtitleLines = subtitles.dropLast().map { subtitle in
                LyricsLineDto(
                    words: subtitle.text.lyricsNoteIfEmpty,
                    startTimeMs: Int64(subtitle.time.total * 1000),
                    syllables: nil
                )
            }

            subtitleLines.append(
                LyricsLineDto(
                    words: "",
                    startTimeMs: Int64(subtitles.last!.time.total * 1000),
                    syllables: nil
                )
            )

            // 处理翻译
            if selectedLanguage != subLanguage,
                let subtitleTranslated = subtitle["subtitle_translated"] as? [String: Any],
                let subtitleTranslatedBody = subtitleTranslated["subtitle_body"] as? String,
                let subtitlesTranslated = try? JSONDecoder().decode(
                    [MusixmatchSubtitle].self, from: subtitleTranslatedBody.data(using: .utf8)!
                )
            {
                if selectedLanguage == romanizationLanguage {
                    romanized = true
                    for (index, subtitleTranslated) in subtitlesTranslated.enumerated() {
                        if index < subtitleLines.count && !subtitleTranslated.text.isEmpty {
                            subtitleLines[index].words = subtitleTranslated.text
                        }
                    }
                } else {
                    translation = LyricsTranslationDto(
                        languageCode: selectedLanguage,
                        lines: subtitlesTranslated.map { $0.text }
                    )
                }
            }

            // 罗马音处理
            if options.romanization && selectedLanguage != romanizationLanguage {
                if let translations = try? getTranslations(
                    query.spotifyTrackId,
                    selectedLanguage: romanizationLanguage
                ) {
                    romanized = true
                    for (original, translationText) in translations {
                        for i in 0..<subtitleLines.count {
                            if subtitleLines[i].words == original {
                                subtitleLines[i].words = translationText
                            }
                        }
                    }
                }
            }
        }

        // ========== 第三步：合并结果 ==========
        let finalLines: [LyricsLineDto]
        let isSyllableSynced: Bool
        let timeSynced: Bool
        
        if hasRichSync && !richsyncLines.isEmpty {
            // 使用逐字歌词，但需要合并翻译
            finalLines = richsyncLines
            isSyllableSynced = true
            timeSynced = true
            
            // 如果字幕有翻译，尝试按行对齐
            if translation != nil && !subtitleLines.isEmpty {
                var alignedTranslations: [String] = Array(repeating: "", count: richsyncLines.count)
                
                for (index, richLine) in richsyncLines.enumerated() {
                    if let richStartTime = richLine.startTimeMs {
                        // 找到时间最接近的字幕行
                        var closestIndex = -1
                        var minDiff = Int64.max
                        
                        for (subIndex, subLine) in subtitleLines.enumerated() {
                            if let subStartTime = subLine.startTimeMs {
                                let diff = abs(richStartTime - subStartTime)
                                if diff < minDiff {
                                    minDiff = diff
                                    closestIndex = subIndex
                                }
                            }
                        }
                        
                        if closestIndex >= 0 && closestIndex < (translation?.lines.count ?? 0) {
                            alignedTranslations[index] = translation?.lines[closestIndex] ?? ""
                        }
                    }
                }
                
                translation = LyricsTranslationDto(
                    languageCode: translation?.languageCode ?? selectedLanguage,
                    lines: alignedTranslations
                )
            }
        } else if !subtitleLines.isEmpty {
            // 使用普通行同步歌词
            finalLines = subtitleLines
            isSyllableSynced = false
            timeSynced = true
        } else {
            // 降级到纯文本歌词
            if let trackLyricsGet = macroCalls["track.lyrics.get"] as? [String: Any],
                let lyricsMessage = trackLyricsGet["message"] as? [String: Any],
                let lyricsHeader = lyricsMessage["header"] as? [String: Any],
                let lyricsStatusCode = lyricsHeader["status_code"] as? Int
            {
                if lyricsStatusCode == 404 {
                    throw LyricsError.noSuchSong
                }

                if let lyricsBody = lyricsMessage["body"] as? [String: Any],
                    let lyrics = lyricsBody["lyrics"] as? [String: Any],
                    let plainLyrics = lyrics["lyrics_body"] as? String
                {
                    if let restricted = lyrics["restricted"] as? Bool, restricted {
                        throw LyricsError.musixmatchRestricted
                    }

                    finalLines = plainLyrics
                        .components(separatedBy: "\n")
                        .dropLast()
                        .map { LyricsLineDto(words: $0.lyricsNoteIfEmpty, startTimeMs: nil, syllables: nil) }
                    isSyllableSynced = false
                    timeSynced = false
                } else {
                    throw LyricsError.decodingError
                }
            } else {
                throw LyricsError.decodingError
            }
        }

        // 处理罗马化状态
        var romanizationStatus = LyricsRomanizationStatus.original
        if romanized {
            romanizationStatus = .romanized
        } else if !hasRichSync, let lang = subtitleLanguage, lang.isCanBeRomanizedLanguage {
            romanizationStatus = .canBeRomanized
        }

        let lyricsDto = LyricsDto(
            lines: finalLines,
            timeSynced: timeSynced,
            isSyllableSynced: isSyllableSynced,
            romanization: romanizationStatus,
            translation: translation
        )

        lyricsCache.setObject(CachedLyrics(dto: lyricsDto), forKey: cacheKey as NSString)
        return lyricsDto
    }
}