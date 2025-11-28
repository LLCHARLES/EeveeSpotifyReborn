// ColorLyricsResponse.pb.swift
import Foundation
import SwiftProtobuf

// 主响应结构
public struct ColorLyricsResponse: SwiftProtobuf.Message {
    public static let protoMessageName: String = "ColorLyricsResponse"
    
    public var lyrics: LyricsResponse?
    public var colors: ColorData?
    public var hasVocalRemoval: Bool = false
    public var vocalRemovalColors: ColorData?
    
    public init() {}
    
    public init(
        lyrics: LyricsResponse? = nil,
        colors: ColorData? = nil,
        hasVocalRemoval: Bool = false,
        vocalRemovalColors: ColorData? = nil
    ) {
        self.lyrics = lyrics
        self.colors = colors
        self.hasVocalRemoval = hasVocalRemoval
        self.vocalRemovalColors = vocalRemovalColors
    }
    
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularMessageField(value: &lyrics)
            case 2: try decoder.decodeSingularMessageField(value: &colors)
            case 3: try decoder.decodeSingularBoolField(value: &hasVocalRemoval)
            case 4: try decoder.decodeSingularMessageField(value: &vocalRemovalColors)
            default: break
            }
        }
    }
    
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let v = lyrics {
            try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
        }
        if let v = colors {
            try visitor.visitSingularMessageField(value: v, fieldNumber: 2)
        }
        if hasVocalRemoval != false {
            try visitor.visitSingularBoolField(value: hasVocalRemoval, fieldNumber: 3)
        }
        if let v = vocalRemovalColors {
            try visitor.visitSingularMessageField(value: v, fieldNumber: 4)
        }
    }
}

// 歌词响应结构
public struct LyricsResponse: SwiftProtobuf.Message {
    public static let protoMessageName: String = "LyricsResponse"
    
    public var syncType: SyncTypeEnum = .unsynced
    public var lines: [LyricsLine] = []
    public var provider: String = ""
    public var providerLyricsId: String = ""
    public var providerDisplayName: String = ""
    public var syncLyricsUri: String = ""
    public var isDenseTypeface: Bool = false
    public var alternatives: [AlternativeLanguages] = []
    public var language: String = ""
    public var isRtlLanguage: Bool = false
    public var fullscreenAction: Int32 = 0
    
    public init() {}
    
    public init(
        syncType: SyncTypeEnum = .unsynced,
        lines: [LyricsLine] = [],
        provider: String = "",
        providerDisplayName: String = ""
    ) {
        self.syncType = syncType
        self.lines = lines
        self.provider = provider
        self.providerDisplayName = providerDisplayName
    }
    
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularEnumField(value: &syncType)
            case 2: try decoder.decodeRepeatedMessageField(value: &lines)
            case 3: try decoder.decodeSingularStringField(value: &provider)
            case 4: try decoder.decodeSingularStringField(value: &providerLyricsId)
            case 5: try decoder.decodeSingularStringField(value: &providerDisplayName)
            case 7: try decoder.decodeSingularStringField(value: &syncLyricsUri)
            case 8: try decoder.decodeSingularBoolField(value: &isDenseTypeface)
            case 9: try decoder.decodeRepeatedMessageField(value: &alternatives)
            case 10: try decoder.decodeSingularStringField(value: &language)
            case 11: try decoder.decodeSingularBoolField(value: &isRtlLanguage)
            case 12: try decoder.decodeSingularInt32Field(value: &fullscreenAction)
            default: break
            }
        }
    }
    
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if syncType != .unsynced {
            try visitor.visitSingularEnumField(value: syncType, fieldNumber: 1)
        }
        if !lines.isEmpty {
            try visitor.visitRepeatedMessageField(value: lines, fieldNumber: 2)
        }
        if !provider.isEmpty {
            try visitor.visitSingularStringField(value: provider, fieldNumber: 3)
        }
        if !providerLyricsId.isEmpty {
            try visitor.visitSingularStringField(value: providerLyricsId, fieldNumber: 4)
        }
        if !providerDisplayName.isEmpty {
            try visitor.visitSingularStringField(value: providerDisplayName, fieldNumber: 5)
        }
        if !syncLyricsUri.isEmpty {
            try visitor.visitSingularStringField(value: syncLyricsUri, fieldNumber: 7)
        }
        if isDenseTypeface != false {
            try visitor.visitSingularBoolField(value: isDenseTypeface, fieldNumber: 8)
        }
        if !alternatives.isEmpty {
            try visitor.visitRepeatedMessageField(value: alternatives, fieldNumber: 9)
        }
        if !language.isEmpty {
            try visitor.visitSingularStringField(value: language, fieldNumber: 10)
        }
        if isRtlLanguage != false {
            try visitor.visitSingularBoolField(value: isRtlLanguage, fieldNumber: 11)
        }
        if fullscreenAction != 0 {
            try visitor.visitSingularInt32Field(value: fullscreenAction, fieldNumber: 12)
        }
    }
}

// 歌词行结构
public struct LyricsLine: SwiftProtobuf.Message {
    public static let protoMessageName: String = "LyricsLine"
    
    public var startTimeMs: Int64 = 0
    public var words: String = ""
    public var syllables: [Syllable] = []
    
    public init() {}
    
    public init(startTimeMs: Int64, words: String) {
        self.startTimeMs = startTimeMs
        self.words = words
    }
    
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularInt64Field(value: &startTimeMs)
            case 2: try decoder.decodeSingularStringField(value: &words)
            case 3: try decoder.decodeRepeatedMessageField(value: &syllables)
            default: break
            }
        }
    }
    
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if startTimeMs != 0 {
            try visitor.visitSingularInt64Field(value: startTimeMs, fieldNumber: 1)
        }
        if !words.isEmpty {
            try visitor.visitSingularStringField(value: words, fieldNumber: 2)
        }
        if !syllables.isEmpty {
            try visitor.visitRepeatedMessageField(value: syllables, fieldNumber: 3)
        }
    }
}

// 音节结构（用于逐字歌词）
public struct Syllable: SwiftProtobuf.Message {
    public static let protoMessageName: String = "Syllable"
    
    public var startTimeMs: Int64 = 0
    public var numChars: Int64 = 0
    
    public init() {}
    
    public init(startTimeMs: Int64, numChars: Int64) {
        self.startTimeMs = startTimeMs
        self.numChars = numChars
    }
    
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularInt64Field(value: &startTimeMs)
            case 2: try decoder.decodeSingularInt64Field(value: &numChars)
            default: break
            }
        }
    }
    
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if startTimeMs != 0 {
            try visitor.visitSingularInt64Field(value: startTimeMs, fieldNumber: 1)
        }
        if numChars != 0 {
            try visitor.visitSingularInt64Field(value: numChars, fieldNumber: 2)
        }
    }
}

// 颜色数据结构
public struct ColorData: SwiftProtobuf.Message {
    public static let protoMessageName: String = "ColorData"
    
    public var background: Int32 = 0
    public var text: Int32 = 0
    public var highlightText: Int32 = 0
    
    public init() {}
    
    public init(background: Int32, text: Int32, highlightText: Int32) {
        self.background = background
        self.text = text
        self.highlightText = highlightText
    }
    
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularInt32Field(value: &background)
            case 2: try decoder.decodeSingularInt32Field(value: &text)
            case 3: try decoder.decodeSingularInt32Field(value: &highlightText)
            default: break
            }
        }
    }
    
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if background != 0 {
            try visitor.visitSingularInt32Field(value: background, fieldNumber: 1)
        }
        if text != 0 {
            try visitor.visitSingularInt32Field(value: text, fieldNumber: 2)
        }
        if highlightText != 0 {
            try visitor.visitSingularInt32Field(value: highlightText, fieldNumber: 3)
        }
    }
}

// 替代语言结构
public struct AlternativeLanguages: SwiftProtobuf.Message {
    public static let protoMessageName: String = "AlternativeLanguages"
    
    public var language: String = ""
    public var lines: [String] = []
    public var isRtlLanguage: Bool = false
    
    public init() {}
    
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &language)
            case 2: try decoder.decodeRepeatedStringField(value: &lines)
            case 3: try decoder.decodeSingularBoolField(value: &isRtlLanguage)
            default: break
            }
        }
    }
    
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !language.isEmpty {
            try visitor.visitSingularStringField(value: language, fieldNumber: 1)
        }
        if !lines.isEmpty {
            try visitor.visitRepeatedStringField(value: lines, fieldNumber: 2)
        }
        if isRtlLanguage != false {
            try visitor.visitSingularBoolField(value: isRtlLanguage, fieldNumber: 3)
        }
    }
}

// 同步类型枚举
public enum SyncTypeEnum: SwiftProtobuf.Enum {
    public typealias RawValue = Int
    case unsynced // = 0
    case lineSynced // = 1
    case syllableSynced // = 2
    case UNRECOGNIZED(Int)
    
    public init() {
        self = .unsynced
    }
    
    public init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .unsynced
        case 1: self = .lineSynced
        case 2: self = .syllableSynced
        default: self = .UNRECOGNIZED(rawValue)
        }
    }
    
    public var rawValue: Int {
        switch self {
        case .unsynced: return 0
        case .lineSynced: return 1
        case .syllableSynced: return 2
        case .UNRECOGNIZED(let i): return i
        }
    }
}

// SwiftProtobuf 兼容性扩展
extension SyncTypeEnum: SwiftProtobuf._ProtoNameProviding {
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        0: .same(proto: "UNSYNCED"),
        1: .same(proto: "LINE_SYNCED"),
        2: .same(proto: "SYLLABLE_SYNCED"),
    ]
}

#if swift(>=5.5) && canImport(_Concurrency)
extension ColorLyricsResponse: @unchecked Sendable {}
extension LyricsResponse: @unchecked Sendable {}
extension LyricsLine: @unchecked Sendable {}
extension Syllable: @unchecked Sendable {}
extension ColorData: @unchecked Sendable {}
extension AlternativeLanguages: @unchecked Sendable {}
extension SyncTypeEnum: @unchecked Sendable {}
#endif

// 便捷构造器扩展
extension ColorLyricsResponse {
    public static func with(_ block: (inout ColorLyricsResponse) -> Void) -> ColorLyricsResponse {
        var message = ColorLyricsResponse()
        block(&message)
        return message
    }
}

extension LyricsResponse {
    public static func with(_ block: (inout LyricsResponse) -> Void) -> LyricsResponse {
        var message = LyricsResponse()
        block(&message)
        return message
    }
}

extension LyricsLine {
    public static func with(_ block: (inout LyricsLine) -> Void) -> LyricsLine {
        var message = LyricsLine()
        block(&message)
        return message
    }
}

extension Syllable {
    public static func with(_ block: (inout Syllable) -> Void) -> Syllable {
        var message = Syllable()
        block(&message)
        return message
    }
}

extension ColorData {
    public static func with(_ block: (inout ColorData) -> Void) -> ColorData {
        var message = ColorData()
        block(&message)
        return message
    }
}

extension AlternativeLanguages {
    public static func with(_ block: (inout AlternativeLanguages) -> Void) -> AlternativeLanguages {
        var message = AlternativeLanguages()
        block(&message)
        return message
    }
}
