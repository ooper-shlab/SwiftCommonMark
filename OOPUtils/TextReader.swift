//
//  TextReader.swift
//  OOPUtils
//
//  Created by OOPer in cooperation with shlab.jp, on 2017/12/31.
//
//
/*
 Copyright (c) 2017-2018, OOPer(NAGATA, Atsuyuki)
 All rights reserved.
 
 Use of any parts(functions, classes or any other program language components)
 of this file is permitted with no restrictions, unless you
 redistribute or use this file in its entirety without modification.
 In this case, providing any sort of warranties or not is the user's responsibility.
 
 Redistribution and use in source and/or binary forms, without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

public class TextReader {
    public let filePath: String
    public let encoding: String.Encoding
    
    private var lineBuffer: Data = Data()
    private var fp: UnsafeMutablePointer<FILE>!
    
    public init?(filePath: String, encoding: String.Encoding = .utf8) {
        self.filePath = filePath
        self.encoding = encoding
        fp = fopen(filePath, "rb")
        if fp == nil {
            return nil
        }
    }
    
    public func next() -> String? {
        let BUFSIZE = 1024
        var buffer: [Int8] = Array(repeating: 0, count: BUFSIZE)
        lineBuffer = Data(capacity: BUFSIZE)
        while feof(fp) == 0, let ptr = fgets(&buffer, Int32(BUFSIZE), fp) {
            let len = strlen(ptr)
            if buffer[len - 1] == 0x0A {
                lineBuffer.append(UnsafeRawPointer(ptr).assumingMemoryBound(to: UInt8.self), count: len)
                return String(data: lineBuffer, encoding: encoding)
            } else {
                lineBuffer.append(UnsafeRawPointer(ptr).assumingMemoryBound(to: UInt8.self), count: len)
            }
        }
        return nil
    }
    
    public func dispose() {
        if let fp = self.fp {
            fclose(fp)
            self.fp = nil
        }
    }
    
    deinit {
        dispose()
    }
}
