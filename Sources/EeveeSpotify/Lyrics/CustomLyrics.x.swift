import Orion
import SwiftUI

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
    return text.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? text }

// MARK: - 加载自定义歌词（已修改回退逻辑）
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
        throw LyricsError.invalidSource   // 用户设置不替换，直接抛 invalidSource
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
        
        // 如果当前源不是 Genius 且开启了 Genius 回退，则改为使用 Spotify 原生歌词
        if source == .genius || !UserDefaults.lyricsOptions.geniusFallback {
            throw error
        }
        
        // 回退到 Spotify 原始歌词，不进行替换
        lyricsState = LyricsLoadingState()
        throw LyricsError.invalidSource   // 复用 invalidSource 表示需要回退
    }
    
    lyricsState.isEmpty = lyricsDto.lines.isEmpty
    lyricsState.wasRomanized = lyricsDto.romanization == .romanized
        || (lyricsDto.romanization == .canBeRomanized && UserDefaults.lyricsOptions.romanization)
    lyricsState.loadedSuccessfully = true

    var colorLyricsResponse = ColorLyricsResponse()
    colorLyricsResponse.lyrics = lyricsDto.toSpotifyLyricsData(source: source.description)
    
    return colorLyricsResponse
}

// MARK: - 获取最终歌词数据（含繁体转简体处理）
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
        colorLyricsResponse = try loadCustomLyricsForCurrentTrack()
    } catch let error as LyricsError {
        // 如果错误是 invalidSource，说明需要回退到 Spotify 原生歌词（可能是源设置为 .notReplaced，也可能是自定义源失败后回退）
        if error == .invalidSource, var original = originalLyrics {
            // 将原始歌词繁体转简体
            var lyrics = original.lyrics
            for i in 0..<lyrics.lines.count {
                lyrics.lines[i].words = traditionalToSimplified(lyrics.lines[i].words)
            }
            original.lyrics = lyrics
            colorLyricsResponse = original
        } else {
            throw error
        }
    }
    
    // 颜色处理部分（保持原逻辑）
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