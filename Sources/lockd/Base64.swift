//
//  Base64.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 6/8/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

#if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
    import Foundation
#elseif os(Linux)
    import Cb64
#endif

import SwiftFoundation

extension Base64 {
    
    public static func decode(data: Data) -> Data {
        
        #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
            
            let decodedData = NSData(base64Encoded: data.toFoundation(), options: .ignoreUnknownCharacters)!
            
            return Data(foundation: decodedData)
            
        #elseif os(Linux)
            
            guard bytes.count > 0 else { return bytes }
            
            var decodeState = base64_decodestate()
            
            base64_init_decodestate(&decodeState)
            
            let inputCharArray: [CChar] = data.byteValue.map { (element: Byte) -> CChar in return CChar(element) }
            
            // http://stackoverflow.com/questions/13378815/base64-length-calculation
            let outputBufferSize = ((inputCharArray.count * 3) / 4)
            
            let outputBuffer = UnsafeMutablePointer<CChar>.init(allocatingCapacity: outputBufferSize)
            
            defer { outputBuffer.deallocateCapacity(outputBufferSize) }
            
            let outputBufferCount = base64_decode_block(inputCharArray, CInt(inputCharArray.count), outputBuffer, &decodeState)!
            
            let outputBytes = Data.from(pointer: outputBuffer, length: Int(outputBufferCount))
            
            return outputBytes
            
        #endif
    }
}