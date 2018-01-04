//
//  StringChunk.swift
//  SwiftCommonMark
//
//  Created by OOPer in cooperation with shlab.jp, on 2018/1/2.
//  Copyright © 2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on chunk.h
 https://github.com/commonmark/cmark/blob/master/src/chunk.h
 */

import Foundation

let STRING_CHUNK_EMPTY = StringChunk()

public class StringChunk: StringBufferType {
    static let EmptyData = String()
    
    private(set) var string: String
    var startIndex: String.Index
    var endIndex: String.Index

    init(content: StringBufferType) {
        self.string = content.string
        self.startIndex = content.startIndex
        self.endIndex = content.endIndex
    }

    init(_ string: String, _ startIndex: String.Index, _ endIndex: String.Index) {
        self.string = String(string[startIndex..<endIndex])
        self.startIndex = self.string.startIndex
        self.endIndex = self.string.endIndex
    }
    
    func initialize(_ string: String, _ startIndex: String.Index, _ endIndex: String.Index) {
        self.string = String(string[startIndex..<endIndex])
        self.startIndex = self.string.startIndex
        self.endIndex = self.string.endIndex
    }
    
    init() {
        string = ""
        startIndex = string.startIndex
        endIndex = string.endIndex
    }
    
    func free() {
        string = ""
        startIndex = string.startIndex
        endIndex = string.endIndex
    }
    
    ///offset: valid offset in UTF-8
    func set(_ buf: StringBufferType, offset: Int = 0) {
        let start = buf.string.utf8.index(buf.startIndex, offsetBy: offset)
        self.string = String(buf.string[start...])
        self.startIndex = self.string.startIndex
        self.endIndex = self.string.endIndex
    }
    public func set(_ string: String) {
        self.string = string
        startIndex = string.startIndex
        endIndex = string.endIndex
    }

    convenience init(literal: String) {
        self.init(literal, literal.startIndex, literal.endIndex)
    }
    
    private static var internDict: [String: String] = [:]
    private static func intern(_ str: String) -> String {
        if let interned = internDict[str] {
            return interned
        } else {
            internDict[str] = str
            return str
        }
    }

    func dup(_ startIndex: String.Index, _ endIndex: String.Index) -> StringChunk {
        let c = StringChunk(string, startIndex, endIndex)
        return c
    }
}

extension StringBuffer {
    func bufDetach() -> StringChunk {
        let chunk = StringChunk(content: self)
        self.initialize(capacity: 0)
        return chunk
    }
}
