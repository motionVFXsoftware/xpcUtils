import IOSurface
import Metal
import SwiftyXPC

public let deameonID = "com.motionVFX.aiDeamon"

public enum whisperEndpoints: String {
    case initWhisper
    case decoderPrediction
    case encoderPrediction
    case getLang
    
    public var endpoint: String {
        return "\(deameonID).\(self.rawValue)"
    }
}

public struct mCaptionsBuffers: Sendable, Codable {
    @IOSurfaceForXPC public var ids: IOSurface
    @IOSurfaceForXPC public var len: IOSurface
    @IOSurfaceForXPC public var entropy: IOSurface
    @IOSurfaceForXPC public var prob: IOSurface
    @IOSurfaceForXPC public var mel: IOSurface
    @IOSurfaceForXPC public var langMask: IOSurface
    @IOSurfaceForXPC public var aligTokens: IOSurface
    
    public init(ids: IOSurface, len: IOSurface, entropy: IOSurface, prob: IOSurface, mel: IOSurface, langMask: IOSurface, aligTokens: IOSurface) {
        self.ids = ids
        self.len = len
        self.entropy = entropy
        self.prob = prob
        self.mel = mel
        self.langMask = langMask
        self.aligTokens = aligTokens
    }
}

public struct whisperResponse {
    public struct getLang: Sendable, Codable {
        public let lang: Int32?
        public let error: WhisperXPCError?
        
        public init(lang: Int32?, error: WhisperXPCError?) {
            self.lang = lang
            self.error = error
        }
    }
    
    public struct whisperInit: Sendable, Codable {
        public let mCaptionsBuffers: mCaptionsBuffers?
        public let error: WhisperXPCError?
        
        public init(mCaptionsBuffers: mCaptionsBuffers?, error: WhisperXPCError?) {
            self.mCaptionsBuffers = mCaptionsBuffers
            self.error = error
        }
    }
    
    public struct baseRequest: Sendable, Codable {
        public let error: WhisperXPCError?
        
        public init(error: WhisperXPCError?) {
            self.error = error
        }
    }
}

public enum WhisperXPCError: Error, Codable, Sendable {
    case whisperNotInitialized
    case invalidParameters
    case cannotInitalizeModel
    case unowned
}
