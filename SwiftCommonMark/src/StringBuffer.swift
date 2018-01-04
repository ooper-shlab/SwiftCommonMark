//
//  StringBuffer.swift
//  SwiftCommonMark
//
//  Created by OOPer in cooperation with shlab.jp, on 2018/1/2.
//  Copyright © 2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on buffer.c and buffer.h
 https://github.com/commonmark/cmark/blob/master/src/buffer.c
 https://github.com/commonmark/cmark/blob/master/src/buffer.h
 */

import Foundation

internal protocol StringBufferType: class {
    var string: String {get}
    var startIndex: String.UnicodeScalarIndex {get set}
    var endIndex: String.UnicodeScalarIndex {get set}
}

extension StringBufferType {
    
    ///### offset: valid UTF-8 offset
    subscript(offset: Int) -> UnicodeScalar {
        if let index = string.utf8.index(startIndex, offsetBy: offset, limitedBy: endIndex) {
            return string.unicodeScalars[index]
        } else {
            return "\0"
        }
    }
    
    ///### offset: valid UnicodeScalar index in `string`
    public subscript(index: String.Index) -> UnicodeScalar {
        if index < endIndex {
            return string.unicodeScalars[index]
        } else {
            return "\0"
        }
    }

    ///### String length in UTF-8.
    public var len: Int {
        return string.utf8.distance(from: startIndex, to: endIndex)
    }
    
    ///### String size in UTF-8.
    public var size: Int {
        return string.utf8.distance(from: startIndex, to: endIndex)
    }

    public var isEmpty: Bool {
        return startIndex == endIndex
    }
    
    var first: UnicodeScalar? {
        if startIndex < endIndex {
            return string.unicodeScalars[startIndex]
        }
        return nil
    }
    
    var last: UnicodeScalar? {
        if startIndex < endIndex {
            let lastCharIndex = string.unicodeScalars.index(before: endIndex)
            return string.unicodeScalars[lastCharIndex]
        }
        return nil
    }
    
    func ltrim() {
        while let firstChar = self.first, firstChar.isSpace {
            startIndex = string.unicodeScalars.index(after: startIndex)
        }
    }
    
    func rtrim() {
        while let lastChar = self.last, lastChar.isSpace {
            endIndex = string.unicodeScalars.index(before: endIndex)
        }
    }
    
    func trim() {
        ltrim()
        rtrim()
    }
    
    ///### _len: valid UTF-8 length from startIndex
    func truncate(_ _len: Int) {
        var len = _len
        if len < 0 {
            len = 0
        }
        
        if len < size {
            self.endIndex = string.utf8.index(self.startIndex, offsetBy: len)
        }
    }
    ///### endIndex: >= self.startIndex && <= self.endIndex
    func truncate(_ endIndex: String.Index) {
        self.endIndex = endIndex
    }
    
    ///### from: >= self.startIndex && <= self.endIndex
    func start(from: String.Index) {
        self.startIndex = from
    }
    
    ///### len: valid UTF-8 length
    func drop(_ _len: Int) {
        var len = _len
        if len > 0 {
            if len > size {
                len = size
            }
            self.startIndex = string.utf8.index(startIndex, offsetBy: len)
        }
    }

    func strchr(_ c: UInt8, _ from: String.Index) -> String.Index? {
        if
            let foundIndex = string.utf8[from...].index(of: c)
        {
            return foundIndex
        } else {
            return nil
        }
    }

    func index(after index: String.Index) -> String.Index {
        return string.unicodeScalars.index(after: index)
    }
    
    func index(before index: String.Index) -> String.Index {
        return string.unicodeScalars.index(before: index)
    }
    
    func index(_ index: String.Index, offsetBy: Int) -> String.Index {
        return string.utf8.index(index, offsetBy: offsetBy)
    }
    
    func distance(from: String.Index, to: String.Index) -> Int {
        return string.utf8.distance(from: from, to: to)
    }
    
    func position(_ index: String.Index) -> Int {
        return string.utf8.distance(from: startIndex, to: index)
    }
    
    public func toString() -> String {
        return String(string[startIndex..<endIndex])
    }
}

public class StringBuffer: StringBufferType {
    internal(set) var string: String
    internal(set) var startIndex: String.UnicodeScalarIndex
    internal(set) var endIndex: String.UnicodeScalarIndex

    init(string: String) {
        self.string = string
        self.startIndex = string.startIndex
        self.endIndex = string.endIndex
    }
    convenience init() {
        self.init(string: "")
    }
}

extension StringBuffer {
    
    /**
     * Initialize a cmark_strbuf structure.
     *
     * For the cases where CMARK_BUF_INIT cannot be used to do static
     * initialization.
     */
    func initialize(capacity: Int) {
        self.string = ""
        self.startIndex = string.startIndex
        self.endIndex = string.endIndex
        string.reserveCapacity(capacity)
    }
    convenience init(capacity: Int) {
        self.init()
        string.reserveCapacity(capacity)
    }
    
    func reinitialize(_ string: String) {
        self.string = string
        self.startIndex = string.startIndex
        self.endIndex = string.endIndex
    }

    func free() {
        
        initialize(capacity: 0)
    }
    
    func clear() {
        
        initialize(capacity: 0)
    }

    func set(_ string: String, from start: String.Index, to end: String.Index) {
        self.string = string
        self.startIndex = start
        self.endIndex = end
    }
    
    public func putc(_ c: UInt8) {
        if endIndex < string.endIndex {
            string.removeSubrange(endIndex...)
        }
        string.append(Character(UnicodeScalar(c)))
        endIndex = string.endIndex
    }

    func put(_ string: String, _ start: String.Index, _ end: String.Index) {
        if endIndex < self.string.endIndex {
            self.string.removeSubrange(endIndex...)
        }
        self.string += string[start..<end]
        endIndex = self.string.endIndex
    }
    
    func put(_ buf: StringBufferType) {
        if endIndex < string.endIndex {
            string.removeSubrange(endIndex...)
        }
        self.string += buf.string[buf.startIndex..<buf.endIndex]
        endIndex = string.endIndex
    }

    ///### startIndex: valid index in buf.string (may exceed buf.endIndex)
    func put(_ buf: StringBufferType, _ startIndex: String.Index) {
        if endIndex < string.endIndex {
            string.removeSubrange(endIndex...)
        }
        if startIndex <= buf.endIndex {
            self.string += buf.string[startIndex..<buf.endIndex]
        }
        endIndex = string.endIndex
    }

    func put(_ char: UnicodeScalar) {
        if endIndex < string.endIndex {
            string.removeSubrange(endIndex...)
        }
        self.string.append(Character(char))
        endIndex = string.endIndex
    }
    
    func put(_ buf: UnsafePointer<UInt8>, _ len: Int, _ validteUTF8: Bool) {
        if validteUTF8 {
            self.utf8procCheck(buf, len)
        } else {
            self.put(buf, len)
        }
    }
    func put(_ _buf: UnsafePointer<UInt8>, _ _len: Int) {
        if endIndex < string.endIndex {
            string.removeSubrange(endIndex...)
        }
        var buf = _buf
        var len = _len
        while len > 0 {
            var ch: Int32 = 0
            let length = cmark_utf8proc_iterate(buf, len, &ch)
            if length < 0 {
                break
            }
            string.append(Character(UnicodeScalar(UInt32(ch))!))
            len -= length
            buf += length
        }
        endIndex = string.endIndex
    }

    func puts(_ string: String) {
        if endIndex < self.string.endIndex {
            self.string.removeSubrange(endIndex...)
        }
        self.string += string
        endIndex = self.string.endIndex
    }

    func detach() -> String {
        let result = string
        self.initialize(capacity: 0)
        return result
    }
    
    // Destructively modify string, collapsing consecutive
    // space and newline characters into a single space.
    func normalizeWhitespace() {
        var lastCharWasSpace = false
        var result = ""
        
        var index = startIndex
        let usv = string.unicodeScalars
        while index < endIndex {
            if usv[index].isSpace {
                if !lastCharWasSpace {
                    result.append(" ")
                    lastCharWasSpace = true
                }
            } else {
                result.append(Character(usv[index]))
                lastCharWasSpace = false
            }
            index = usv.index(after: index)
        }
        
        reinitialize(result)
    }
    
    // Destructively unescape a string: remove backslashes before punctuation chars.
    func unescape() {
        var result = ""
        
        var index = startIndex
        let usv = string.unicodeScalars
        while index < endIndex {
            let index_1 = usv.index(after: index)
            if usv[index] == "\\" && usv[index_1].isPunct {
                index = index_1
            }
            
            result.append(Character(usv[index]))
            index = usv.index(after: index)
        }
        
        reinitialize(result)
    }
}
