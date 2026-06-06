import Orion
import SwiftUI
import CoreFoundation  // 添加这个导入

struct BaseLyricsGroup: HookGroup { }

struct LegacyLyricsGroup: HookGroup { }
struct ModernLyricsGroup: HookGroup { }

var lyricsState = LyricsLoadingState()

var hasShownRestrictedPopUp = false
var hasShownUnauthorizedPopUp = false

private let geniusLyricsRepository = GeniusLyricsRepository()
private let petitLyricsRepository = PetitLyricsRepository()

// 添加繁体转简体函数
private func traditionalToSimplified(_ text: String) -> String {
    let mutableString = NSMutableString(string: text) as CFMutableString
    CFStringTransform(mutableString, nil, kCFStringTransformTraditionalChineseToSimplifiedChinese, false)
    return mutableString as String
}

private func loadCustomLyricsForCurrentTrack() throws -> ColorLyricsResponse {
    guard
        let track = statefulPlayer?.currentTrack() ??
                    nowPlayingScrollViewController?.loadedTrack
        else {
            throw LyricsError.noCurrentTrack
        }
    
    let searchQuery = LyricsSearchQuery(
        title: track.trackTitle(),
        primaryArtist: EeveeSpotify.hookTarget == .lastAvailableiOS14
            ? track.artistTitle()
            : track.artistName(),
        spotifyTrackId: track.trackIdentifier
    )
    
    let options = UserDefaults.lyricsOptions
    var source = UserDefaults.lyricsSource
    
    var repository: LyricsRepository

    switch source {
    case .genius:
        repository = geniusLyricsRepository
    case .lrclib:
        repository = LrclibLyricsRepository.shared
    case .musixmatch:
        repository = MusixmatchLyricsRepository.shared
    case .petit:
        repository = petitLyricsRepository
    case .notReplaced:
        throw LyricsError.invalidSource
    }
    
    let lyricsDto: LyricsDto
    
    lyricsState = LyricsLoadingState()
    
    do {
        lyricsDto = try repository.getLyrics(searchQuery, options: options)
    }
    catch let error {
        if let error = error as? LyricsError {
            lyricsState.fallbackError = error
            
            switch error {
                
            case .invalidMusixmatchToken:
                if !hasShownUnauthorizedPopUp {
                    PopUpHelper.showPopUp(
                        delayed: false,
                        message: "musixmatch_unauthorized_popup".localized,
                        buttonText: "OK".uiKitLocalized
                    )
                    
                    hasShownUnauthorizedPopUp.toggle()
                }
            
            case .musixmatchRestricted:
                if !hasShownRestrictedPopUp {
                    PopUpHelper.showPopUp(
                        delayed: false,
                        message: "musixmatch_restricted_popup".localized,
                        buttonText: "OK".uiKitLocalized
                    )
                    
                    hasShownRestrictedPopUp.toggle()
                }
                
            default:
                break
            }
        }
        else {
            lyricsState.fallbackError = .unknownError
        }
        
        // LRCLIB 失败时直接回退到 Spotify 原生歌词
        if source == .lrclib {
            throw LyricsError.invalidSource  // 使用原生歌词
        }
        
        if source == .genius || !UserDefaults.lyricsOptions.geniusFallback {
            throw error
        }
        
        source = .genius
        repository = GeniusLyricsRepository()
        
        lyricsDto = try repository.getLyrics(searchQuery, options: options)
    }
    
    // 非回退情况：不转换歌词，保持原样
    lyricsState.isEmpty = lyricsDto.lines.isEmpty
    
    lyricsState.wasRomanized = lyricsDto.romanization == .romanized
        || (lyricsDto.romanization == .canBeRomanized && UserDefaults.lyricsOptions.romanization)
    
    lyricsState.loadedSuccessfully = true

    var colorLyricsResponse = ColorLyricsResponse()
    colorLyricsResponse.lyrics = lyricsDto.toSpotifyLyricsData(source: source.description)
    
    return colorLyricsResponse
}

func getLyricsDataForCurrentTrack(_ originalPath: String, originalLyrics: ColorLyricsResponse? = nil) throws -> Data {
    guard
        let track = statefulPlayer?.currentTrack() ??
                    nowPlayingScrollViewController?.loadedTrack
        else {
            throw LyricsError.noCurrentTrack
        }
    
    let trackIdentifier = track.trackIdentifier
    
    if !trackIdentifier.isEmpty && !originalPath.contains(trackIdentifier) {
        throw LyricsError.trackMismatch
    }
    
    var colorLyricsResponse: ColorLyricsResponse
    
    do {
        // 尝试获取自定义歌词
        colorLyricsResponse = try loadCustomLyricsForCurrentTrack()
    } catch LyricsError.invalidSource {
        // 只有 LRCLIB 失败回退到原生歌词时才转换繁体到简体
        guard let originalLyrics = originalLyrics else {
            throw LyricsError.noSuchSong
        }
        
        colorLyricsResponse = originalLyrics
        
        // 将 Spotify 原生歌词从繁体转换为简体
        var convertedLyricsData = colorLyricsResponse.lyrics
        
        // 转换普通歌词行 (LyricsLine 使用 words 属性)
        var convertedLines: [LyricsLine] = []
        for line in convertedLyricsData.lines {
            var convertedLine = line
            convertedLine.words = traditionalToSimplified(line.words)
            convertedLines.append(convertedLine)
        }
        convertedLyricsData.lines = convertedLines
        
        // 转换替代语言/翻译行 (如果有)
        var convertedAlternatives: [AlternativeLanguages] = []
        for alternative in convertedLyricsData.alternatives {
            var convertedAlternative = alternative
            var convertedAltLines: [String] = []
            for line in alternative.lines {
                convertedAltLines.append(traditionalToSimplified(line))
            }
            convertedAlternative.lines = convertedAltLines
            convertedAlternatives.append(convertedAlternative)
        }
        convertedLyricsData.alternatives = convertedAlternatives
        
        colorLyricsResponse.lyrics = convertedLyricsData
    } catch {
        throw error
    }
    
    let lyricsColorsSettings = UserDefaults.lyricsColors
    
    if lyricsColorsSettings.displayOriginalColors, let originalLyrics = originalLyrics {
        colorLyricsResponse.colors = originalLyrics.colors
    }
    else {
        let extractedColor = switch EeveeSpotify.hookTarget {
        case .lastAvailableiOS14:
            track.extractedColorHex()
        default:
            track.metadata()["extracted_color"]
        }
        
        var color: Color
        
        if lyricsColorsSettings.useStaticColor {
            color = Color(hex: lyricsColorsSettings.staticColor)
        }
        else if let extractedColor = extractedColor {
            color = Color(hex: extractedColor)
                .normalized(lyricsColorsSettings.normalizationFactor)
        }
        else if let uiColor = backgroundViewModel?.color() {
            color = Color(uiColor)
                .normalized(lyricsColorsSettings.normalizationFactor)
        }
        else {
            color = Color.gray
        }
        
        var colorData = ColorData()
        colorData.background = Int32(bitPattern: color.uInt32)
        colorData.text = Int32(bitPattern: Color.black.uInt32)
        colorData.highlightText = Int32(bitPattern: Color.white.uInt32)
        
        colorLyricsResponse.colors = colorData
    }
    
    return try colorLyricsResponse.serializedBytes()
}