import IOSurface
import Metal
import SwiftyXPC
import xpcMacros
public let deameonID = "com.motionVFX.aiDeamon"

public extension IOSurfaceRef {
    func asMTLBuffer(_ device: MTLDevice) -> MTLBuffer {
        guard let buffer = device.makeBuffer(bytesNoCopy: IOSurfaceGetBaseAddress(self), length: IOSurfaceGetAllocSize(self), options: [.storageModeShared]) else {
            fatalError("Couldn't allocate buffer from IOSurfaceRef")
        }
        return buffer
    }
}


public enum whisperEndpoints: String {
    case initWhisper
    case decoderPrediction
    case encoderPrediction
    case getLang
    case decoder64Prediction
    case decoder192Prediction
    case deinitWhisper
    case getBuffers
    case checkStatus
    case saveCache
    
    public var endpointName: String {
        return "\(deameonID).\(self.rawValue)"
    }
}


public struct decocerParams: Sendable, Codable {
    @IOSurfaceForXPC public var paddingMaskParams: IOSurfaceRef
    public let withAlignment: Bool
//    public var event: SendableMTLEvent
    
    public init(paddingMaskParams: IOSurfaceRef, withAlignment: Bool = false) {
        self.paddingMaskParams = paddingMaskParams
        self.withAlignment = withAlignment
//        self.event = event
    }
}


public struct mCaptionsBuffers: Sendable, Codable {
    @IOSurfaceForXPC public var ids: IOSurfaceRef
    @IOSurfaceForXPC public var len: IOSurfaceRef
    @IOSurfaceForXPC public var entropy: IOSurfaceRef
    @IOSurfaceForXPC public var prob: IOSurfaceRef
    @IOSurfaceForXPC public var mel: IOSurfaceRef
    @IOSurfaceForXPC public var langMask: IOSurfaceRef
    @IOSurfaceForXPC public var specialTokenMask: IOSurfaceRef
    @IOSurfaceForXPC public var aligTokens: IOSurfaceRef
    @IOSurfaceForXPC public var encOut: IOSurfaceRef
    @IOSurfaceForXPC public var resBuffer96: IOSurfaceRef
    @IOSurfaceForXPC public var resBuffer192: IOSurfaceRef
    @IOSurfaceForXPC public var maskBuffer96: IOSurfaceRef
    @IOSurfaceForXPC public var maskBuffer192: IOSurfaceRef
//    @IOSurfaceForXPC public var langBuffer: IOSurfaceRef
    
    public var decOut96: [IOSurfaceForXPC]
    public var decOut192: [IOSurfaceForXPC]

    public init(ids: IOSurfaceRef, len: IOSurfaceRef, entropy: IOSurfaceRef, prob: IOSurfaceRef, mel: IOSurfaceRef, langMask: IOSurfaceRef, aligTokens: IOSurfaceRef, specialTokenMask: IOSurfaceRef, resBuffer96: IOSurfaceRef, resBuffer192: IOSurfaceRef, encOut: IOSurfaceRef, maskBuffer96: IOSurfaceRef, maskBuffer192: IOSurfaceRef, decOut96: [IOSurfaceRef], decOut192: [IOSurfaceRef]) {
        self.ids = ids
        self.len = len
        self.entropy = entropy
        self.prob = prob
        self.mel = mel
        self.langMask = langMask
        self.aligTokens = aligTokens
        self.specialTokenMask = specialTokenMask
        self.decOut96 = decOut96.map { IOSurfaceForXPC(wrappedValue: $0) }
        self.decOut192 = decOut192.map { IOSurfaceForXPC(wrappedValue: $0) }
        self.encOut = encOut
        self.resBuffer96 = resBuffer96
        self.resBuffer192 = resBuffer192
        self.maskBuffer96 = maskBuffer96
        self.maskBuffer192 = maskBuffer192
//        self.langBuffer = langBuffer
    }
}

public struct whisperResponse {
    public struct getLang: Sendable, Codable {
        public let lang: Int32?
        public let probability: Float32?
        public let entropy: Float32?
        public let error: WhisperXPCError?
        
        public init(lang: Int32?, probability: Float32?, entropy: Float32?, error: WhisperXPCError?) {
            self.lang = lang
            self.probability = probability
            self.entropy = entropy
            self.error = error
        }
    }
    
    public struct initWhisper: Sendable, Codable {
        public let status: initStatus
        public let error: WhisperXPCError?
        
        public init(status: initStatus, error: WhisperXPCError?) {
            self.status = status
            self.error = error
        }
    }
    
    public struct getBuffers: Sendable, Codable {
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
    case noModelFile(String)
    case noModelCache(String)
    case cantAccessLibrary
    case cantAllocateMemory
    case systemVersionNotSupported(Int)
    case cantPrepareDevice(Int)
    case deviceNotPrepared
    case modelsNotCompiled
    
    case noError
}

public enum initStatus: Sendable, Codable {
    case initialized, waiting, failed, notInitialized
}

public enum MPSGraphComputeDevice: UInt64, Sendable, Codable {
    case none = 0
    case gpu = 1
    case neuralEngine = 2
    case gpuAndNeuralEngine = 3
    case cpu = 4
    case gpuAndCpu = 5
    case cpuAndNeuralEngine = 6
    case all = 7
}

public enum modelVersion: UInt8, Sendable, Codable {
    case fp16 = 0
    case i8 = 1
}

public struct modelSettings: Sendable, Codable {
    public let encoderDevice: MPSGraphComputeDevice
    public let decoderDevice: MPSGraphComputeDevice
    public let basePath: String
    public let cachePath: String
    public let useCache: Bool
    public let modelVersion: modelVersion
    
    public init(encoderDevice: MPSGraphComputeDevice, decoderDevice: MPSGraphComputeDevice, basePath: String, cachePath: String, useCache: Bool, modelVersion: modelVersion) {
        self.encoderDevice = encoderDevice
        self.decoderDevice = decoderDevice
        self.basePath = basePath
        self.useCache = useCache
        self.modelVersion = modelVersion
        self.cachePath = cachePath
    }
}

//public struct whisperBuffers {
//    let encOutBuffer: IOSurfaceForXPC
//
//    // Decoder
//    let maskBuffer64: IOSurfaceForXPC
//    let maskBuffer192: IOSurfaceForXPC
//    let resBuffer64: IOSurfaceForXPC
//    let resBuffer192: IOSurfaceForXPC
//
//    let crossBuffers64: [IOSurfaceForXPC]
//    let crossBuffers192: [IOSurfaceForXPC]
//
//    // IOSurface buffers
//    let lenBuffer: IOSurfaceForXPC
//    let probBuffer: IOSurfaceForXPC
//    let entropyBuffer: IOSurfaceForXPC
//    let idsBuffer: IOSurfaceForXPC
//    let alignTokensBuffer: IOSurfaceForXPC
//
//    let melBuffer: IOSurfaceForXPC
//
//    let specialMaskBuffer: IOSurfaceForXPC
//    let langBuffer: IOSurfaceForXPC
//}

public struct LangStats: Sendable, Codable {
    public let lang: Int32, prob: Float32, entropy: Float32
    
    public init(lang: Int32, prob: Float32, entropy: Float32) {
        self.lang = lang
        self.prob = prob
        self.entropy = entropy
    }
}

public struct decoderParams: Sendable, Codable {
    let curLen: Int
    let params: IOSurfaceForXPC
    let withAlignment: Bool
    
    public init(curLen: Int, params: IOSurfaceForXPC, withAlignment: Bool) {
        self.curLen = curLen
        self.params = params
        self.withAlignment = withAlignment
    }
}

@GenerateCodableClient
@GenerateCodableServer
public protocol WhisperTurbo {
    var error: WhisperXPCError { get set }
    var status: initStatus { get set }
    
    func getLanguage() async throws -> LangStats
    func decoderForward(decoderParams: decoderParams) async throws -> WhisperXPCError
    func encoderForward() async throws -> WhisperXPCError
    
    func loadModels(withSettings: modelSettings) async throws -> WhisperXPCError
    func serializeModels(withSettings: modelSettings) async throws -> WhisperXPCError
    func prepareDevice(deviceID: Int) async throws -> WhisperXPCError

    func checkStatus() async throws -> initStatus
    func checkError() async throws -> WhisperXPCError
    func cleanModels() async throws -> WhisperXPCError
    func getIOSurfaceBuffers() async throws -> mCaptionsBuffers
    
    func resetAllBuffers() async throws -> WhisperXPCError
    func resetDecoderBuffers() async throws -> WhisperXPCError

}
