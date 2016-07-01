//
//  Base64.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 6/25/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import SwiftFoundation

#if os(Linux)
    import Cb64
#elseif os(OSX)
    import b64
#endif

/// [Base64](https://en.wikipedia.org/wiki/Base64) encoding.
///
/// - Note: Uses the [libb64](http://libb64.sourceforge.net) engine.
public struct Base64 {
    
    static public func decode(_ data: Data) -> Data {
        
        guard data.bytes.count > 0 else { return data }
        
        var decodeState = base64_decodestate()
        
        base64_init_decodestate(&decodeState)
        
        let inputCharArray: [CChar] = data.bytes.map { (element: Byte) -> CChar in return CChar(element) }
        
        // http://stackoverflow.com/questions/13378815/base64-length-calculation
        let outputBufferSize = ((inputCharArray.count * 3) / 4)
        
        let outputBuffer = UnsafeMutablePointer<CChar>.init(allocatingCapacity: outputBufferSize)
        
        defer { outputBuffer.deallocateCapacity(outputBufferSize) }
        
        let outputBufferCount = base64_decode_block(inputCharArray, CInt(inputCharArray.count), outputBuffer, &decodeState)
        
        let outputBytes = Data(bytes: UnsafePointer<UInt8>(outputBuffer), count: Int(outputBufferCount))
        
        return outputBytes
    }
}
