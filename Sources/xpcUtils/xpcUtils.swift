import IOSurface
import Metal
import SwiftyXPC
public let deameonID = "com.motionVFX.aiDeamon"

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

public struct SendableMTLEvent: Sendable, Codable {
    private let handleData: Data

    public init(from eventHandle: MTLSharedEventHandle) throws {
        self.handleData = try NSKeyedArchiver.archivedData(
            withRootObject: eventHandle,
            requiringSecureCoding: true
        )
    }

    public func makeEventHandle() throws -> MTLSharedEventHandle {
        guard let handle = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: MTLSharedEventHandle.self,
            from: handleData
        ) else {
            throw MTLEventError.invalidHandle
        }
        return handle
    }

    public func makeSharedEvent(device: MTLDevice) throws -> MTLSharedEvent {
        let handle = try makeEventHandle()
        guard let event = device.makeSharedEvent(handle: handle) else {
            throw MTLEventError.deviceCreationFailed
        }
        return event
    }
}

public enum MTLEventError: Error {
    case invalidHandle
    case deviceCreationFailed
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
    
    public init(ids: IOSurfaceRef, len: IOSurfaceRef, entropy: IOSurfaceRef, prob: IOSurfaceRef, mel: IOSurfaceRef, langMask: IOSurfaceRef, aligTokens: IOSurfaceRef, specialTokenMask: IOSurfaceRef) {
        self.ids = ids
        self.len = len
        self.entropy = entropy
        self.prob = prob
        self.mel = mel
        self.langMask = langMask
        self.aligTokens = aligTokens
        self.specialTokenMask = specialTokenMask
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
    public let useCache: Bool
    public let deviceID: Int
    public let modelVersion: modelVersion
    
    public init(encoderDevice: MPSGraphComputeDevice, decoderDevice: MPSGraphComputeDevice, basePath: String, useCache: Bool, deviceID: Int, modelVersion: modelVersion) {
        self.encoderDevice = encoderDevice
        self.decoderDevice = decoderDevice
        self.basePath = basePath
        self.useCache = useCache
        self.deviceID = deviceID
        self.modelVersion = modelVersion
    }
}
