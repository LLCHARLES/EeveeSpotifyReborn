import Orion
import SwiftUI

//

struct LyricsGroup: HookGroup { }

var lyricsState = LyricsLoadingState()

var hasShownRestrictedPopUp = false
var hasShownUnauthorizedPopUp = false

private let geniusLyricsRepository = GeniusLyricsRepository()
private let petitLyricsRepository = PetitLyricsRepository()

//

private func loadCustomLyricsForCurrentTrack() throws -> LyricsDto {
    guard let track = nowPlayingScrollViewController?.loadedTrack else {
        throw LyricsError.noCurrentTrack
    }
    
    let searchQuery = LyricsSearchQuery(
        title: track.trackTitle(),
        primaryArtist: EeveeSpotify.hookTarget == .lastAvailableiOS14
            ? track.artistTitle()
            : track.artistName(),
        spotifyTrackId: track.URI().spt_trackIdentifier()
    )
    
    let options = UserDefaults.lyricsOptions
    var source = UserDefaults.lyricsSource
    
    // switched to swift 5.8 syntax to compile with Theos on Linux.
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
        
        if source == .genius || !UserDefaults.lyricsOptions.geniusFallback {
            throw error
        }
        
        source = .genius
        repository = GeniusLyricsRepository()
        
        lyricsDto = try repository.getLyrics(searchQuery, options: options)
    }
    
    lyricsState.isEmpty = lyricsDto.lines.isEmpty
    
    lyricsState.wasRomanized = lyricsDto.romanization == .romanized
        || (lyricsDto.romanization == .canBeRomanized && UserDefaults.lyricsOptions.romanization)
    
    lyricsState.loadedSuccessfully = true

    return lyricsDto
}

func getLyricsDataForCurrentTrack(originalLyrics: ColorLyricsResponse? = nil) throws -> Data {
    guard let track = nowPlayingScrollViewController?.loadedTrack else {
        throw LyricsError.noCurrentTrack
    }
    
    let lyricsDto = try loadCustomLyricsForCurrentTrack()
    var colorLyricsResponse = lyricsDto.toSpotifyLyricsData(source: UserDefaults.lyricsSource.description)
    
    // 处理颜色设置
    let lyricsColorsSettings = UserDefaults.lyricsColors
    
    if lyricsColorsSettings.displayOriginalColors, let originalLyrics = originalLyrics {
        // 使用原始响应的颜色
        colorLyricsResponse.colors = originalLyrics.colors
        colorLyricsResponse.vocalRemovalColors = originalLyrics.vocalRemovalColors
    } else {
        // 应用自定义颜色逻辑
        let extractedColor = extractColor(from: track)
        let backgroundColor = calculateBackgroundColor(extractedColor: extractedColor, settings: lyricsColorsSettings)
        
        var colorData = ColorData()
        colorData.background = backgroundColor.uInt32
        colorData.text = Color.white.uInt32
        colorData.highlightText = Color.yellow.uInt32
        
        colorLyricsResponse.colors = colorData
    }
    
    return try colorLyricsResponse.serializedData()
}

// 辅助函数
private func extractColor(from track: AnyObject) -> String? {
    return switch EeveeSpotify.hookTarget {
    case .lastAvailableiOS14:
        track.extractedColorHex()
    default:
        track.metadata()["extracted_color"]
    }
}

private func calculateBackgroundColor(extractedColor: String?, settings: LyricsColorsSettings) -> Color {
    var color: Color
    
    if settings.useStaticColor {
        color = Color(hex: settings.staticColor)
    }
    else if let extractedColor = extractedColor {
        color = Color(hex: extractedColor)
            .normalized(settings.normalizationFactor)
    }
    else if let uiColor = nowPlayingScrollViewController?.backgroundViewModel.color() {
        color = Color(uiColor)
            .normalized(settings.normalizationFactor)
    }
    else {
        color = Color.gray
    }
    
    return color
}
