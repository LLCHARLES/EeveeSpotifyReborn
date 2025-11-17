import Foundation

struct LrclibSong: Decodable {
    var name: String
    var plainLyrics: String?
    var syncedLyrics: String?
    var translatedLyrics: String?  // 添加翻译歌词字段
    var instrumental: Bool
}
