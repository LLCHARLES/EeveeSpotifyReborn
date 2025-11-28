import Foundation

struct LrclibSong: Decodable {
    var name: String
    var plainLyrics: String?
    var syncedLyrics: String?
    var yrcLyrics: String?  // 逐字歌词字段
    var instrumental: Bool
    var translatedLyrics: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case plainLyrics
        case syncedLyrics
        case yrcLyrics
        case instrumental
        case translatedLyrics
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        plainLyrics = try container.decodeIfPresent(String.self, forKey: .plainLyrics)
        syncedLyrics = try container.decodeIfPresent(String.self, forKey: .syncedLyrics)
        yrcLyrics = try container.decodeIfPresent(String.self, forKey: .yrcLyrics)
        instrumental = try container.decode(Bool.self, forKey: .instrumental)
        translatedLyrics = try container.decodeIfPresent(String.self, forKey: .translatedLyrics)
    }
    
    init(
        name: String,
        plainLyrics: String? = nil,
        syncedLyrics: String? = nil,
        yrcLyrics: String? = nil,
        instrumental: Bool,
        translatedLyrics: String? = nil
    ) {
        self.name = name
        self.plainLyrics = plainLyrics
        self.syncedLyrics = syncedLyrics
        self.yrcLyrics = yrcLyrics
        self.instrumental = instrumental
        self.translatedLyrics = translatedLyrics
    }
}
