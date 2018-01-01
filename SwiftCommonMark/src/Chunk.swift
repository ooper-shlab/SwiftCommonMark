//
//  Chunk.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/17.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on chunk.h
 https://github.com/commonmark/cmark/blob/master/src/chunk.h
 */

import Foundation

let CMARK_CHUNK_EMPTY = CmarkChunk()

public class CmarkChunk {
    static let EmptyData: UnsafeMutablePointer<UInt8> = {
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        data.initialize(to: 0)
        return data
    }()
    
    var data: UnsafeMutablePointer<UInt8>
    var len: Int = 0
    var alloc: Int = 0 // also implies a NULL-terminated string
    
    init(content: CmarkStrbuf) {
        data = content.ptr
        len = content.size
        alloc = 0
    }
    init(data: UnsafeMutablePointer<UInt8>, len: Int, alloc: Int) {
        self.data = data
        self.len = len
        self.alloc = alloc
    }
    func initialize(data: UnsafeMutablePointer<UInt8>, len: Int) {
        free()
        self.data = data
        self.len = len
        self.alloc = 0
    }
    init() {
        data = CmarkChunk.EmptyData
        alloc = 0
        len = 0
    }
    
    func free() {
        if alloc != 0 {
            data.deinitialize(count: alloc)
            data.deallocate(capacity: alloc)
        }
        
        data = CmarkChunk.EmptyData
        alloc = 0
        len = 0
    }
    
    func ltrim() {
        assert(alloc == 0)
        
        while len != 0 && data[0].isSpace {
            data += 1
            len -= 1
        }
    }
    
    func rtrim() {
        assert(alloc == 0)
        
        while len > 0 {
            if !data[len - 1].isSpace {
                break
            }
            
            len -= 1
        }
    }
    
    func trim() {
        ltrim()
        rtrim()
    }
    
    func strchr(_ c: UInt8,
                _ offset: Int) -> Int {
        let p: UnsafeMutablePointer<UInt8>? =
            memchr(data + offset, Int32(c), len - offset)?.assumingMemoryBound(to: UInt8.self)
        return p != nil ? p! - data : len
    }
    //
    //static CMARK_INLINE const char *cmark_chunk_to_cstr(cmark_mem *mem,
    //                                                    cmark_chunk *c) {
    //  unsigned char *str;
    //
    //  if (c->alloc) {
    //    return (char *)c->data;
    //  }
    //  str = (unsigned char *)mem->calloc(c->len + 1, 1);
    //  if (c->len > 0) {
    //    memcpy(str, c->data, c->len);
    //  }
    //  str[c->len] = 0;
    //  c->data = str;
    //  c->alloc = 1;
    //
    //  return (char *)str;
    //}
    public func toString() -> String {
        if alloc != 0 {
            return String(cString: data)
        }
        let buffer = UnsafeBufferPointer(start: data, count: len)
        return String(bytes: buffer, encoding: .utf8)!
    }
    
    public func setCstr(_ str: UnsafePointer<CChar>?) {
        let old: UnsafeMutablePointer<UInt8>? = alloc != 0 ? data : nil
        let oldAlloc = alloc
        if str == nil {
            len = 0
            data = CmarkChunk.EmptyData
            alloc = 0
        } else {
            len = strlen(str)
            data = UnsafeMutablePointer<UInt8>.allocate(capacity: len+1)
            alloc = len+1
            let ptr = UnsafeRawPointer(str!).assumingMemoryBound(to: UInt8.self)
            data.initialize(from: ptr, count: len + 1)
        }
        if let old = old {
            old.deinitialize(count: oldAlloc)
            old.deallocate(capacity: oldAlloc)
        }
    }
    
    init(bytesNoCopy data: UnsafePointer<CChar>?) {
        if let data = data {
            self.len = strlen(data)
            self.data = UnsafeMutableRawPointer(mutating: data).assumingMemoryBound(to: UInt8.self)
            self.alloc = 0
        } else {
            self.len = 0
            self.data = CmarkChunk.EmptyData
            self.alloc = 0
        }
    }
    convenience init(literal: String) {
        let bytes = CmarkChunk.intern(literal)
        self.init(bytesNoCopy: bytes)
    }
    private static var internDict: [String: UnsafePointer<CChar>] = [:]
    private static func intern(_ str: String) -> UnsafePointer<CChar> {
        if let bytes = internDict[str] {
            return bytes
        } else {
            let bytes = UnsafePointer(strdup(str)!)
            internDict[str] = bytes
            return bytes
        }
    }
    
    func dup(pos: Int, len: Int) -> CmarkChunk {
        let c = CmarkChunk(data: data + pos, len: len, alloc: 0)
        return c
    }
}

extension CmarkStrbuf {
    func bufDetach() -> CmarkChunk {
        
        let len = size
        let (ptr, asize) = detachPtr()
        let c = CmarkChunk(data: ptr, len: len, alloc: asize)
        
        return c
    }
}


