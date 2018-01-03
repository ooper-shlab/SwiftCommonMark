//
//  References.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/17.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on references.c and references.h
 https://github.com/commonmark/cmark/blob/master/src/references.c
 https://github.com/commonmark/cmark/blob/master/src/references.h
 */

import Foundation

//let REFMAP_SIZE = 16

class CmarkReference {
    var label: String?
    var url: StringChunk?
    var title: StringChunk?
}

class CmarkReferenceMap {
    var dict: [String: CmarkReference] = [:]
}

extension CmarkReference {
    func free() {
        label = nil
        url?.free()
        title?.free()
    }
}

private func strcmp(_ str1: UnsafePointer<UInt8>, _ str2: UnsafePointer<UInt8>) -> Int32 {
    let ptr1 = UnsafeRawPointer(str1).assumingMemoryBound(to: CChar.self)
    let ptr2 = UnsafeRawPointer(str2).assumingMemoryBound(to: CChar.self)
    return strcmp(ptr1, ptr2)
}

extension StringChunk {
    // normalize reference:  collapse internal whitespace to single space,
    // remove leading/trailing whitespace, case fold
    // Return NULL if the reference name is actually empty (i.e. composed
    // solely from whitespace)
    fileprivate func normalizeReference() -> String? {
        let normalized = StringBuffer()
        
        if isEmpty {
            return nil
        }
        
        normalized.caseFold(self)
        normalized.trim()
        normalized.normalizeWhitespace()
        
        let result = normalized.detach()
        
        if result.isEmpty {
            return nil
        }
        
        return result
    }
}

extension CmarkReferenceMap {
    fileprivate func add(_ ref: CmarkReference) {
        if dict[ref.label!] != nil {
            ref.free()
            return
        }
        dict[ref.label!] = ref
    }
    
    func create(label: StringChunk,
                url: StringChunk, title: StringChunk) {
        guard let reflabel = label.normalizeReference() else {
            
            /* empty reference name, or composed from only whitespace */
            return
        }
        
        let ref = CmarkReference()
        ref.label = reflabel
        ref.url = url.cleanUrl()
        ref.title = title.cleanTitle()
        
        add(ref)
    }
    
    // Returns reference if refmap contains a reference with matching
    // label, otherwise NULL.
    func lookup(
        _ label: StringChunk) -> CmarkReference? {
        
        if label.len < 1 || label.len > MAX_LINK_LABEL_LENGTH {
            return nil
        }
        
        guard let norm = label.normalizeReference() else {
            return nil
        }
        
        return dict[norm]
    }
    
    func free() {
        
        dict = [:]
        
    }
    
}
