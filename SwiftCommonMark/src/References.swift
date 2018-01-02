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

let REFMAP_SIZE = 16

class CmarkReference {
    var next: CmarkReference?
    var label: UnsafeMutablePointer<UInt8>?
    var labelSize: Int = 0
    var url: CmarkChunk?
    var title: CmarkChunk?
    var hash: UInt32 = 0
    
    deinit {
        if labelSize > 0 {
            label?.deinitialize(count: labelSize)
            label?.deallocate(capacity: labelSize)
        }
    }
}

class CmarkReferenceMap {
    var table: [CmarkReference?] = (0..<REFMAP_SIZE).map{_ in CmarkReference()}
}

private func refhash(_ _linkRef: UnsafePointer<UInt8>) -> UInt32 {
    var linkRef = _linkRef
    var hash: UInt32 = 0
    
    while linkRef.pointee != 0 {
        hash = UInt32(linkRef.pointee) &+ (hash &<< 6) &+ (hash &<< 16) &- hash
        linkRef += 1
    }
    
    return hash
}

extension CmarkReference {
    func free() {
        label?.deinitialize(count: labelSize)
        label?.deallocate(capacity: labelSize)
        label = nil
        labelSize = 0
        url?.free()
        title?.free()
    }
}

private func strcmp(_ str1: UnsafePointer<UInt8>, _ str2: UnsafePointer<UInt8>) -> Int32 {
    let ptr1 = UnsafeRawPointer(str1).assumingMemoryBound(to: CChar.self)
    let ptr2 = UnsafeRawPointer(str2).assumingMemoryBound(to: CChar.self)
    return strcmp(ptr1, ptr2)
}

extension CmarkChunk {
    // normalize reference:  collapse internal whitespace to single space,
    // remove leading/trailing whitespace, case fold
    // Return NULL if the reference name is actually empty (i.e. composed
    // solely from whitespace)
    fileprivate func normalizeReference() -> (UnsafePointer<UInt8>?, Int) {
        let normalized = CmarkStrbuf()
        
        if len == 0 {
            return (nil, 0)
        }
        
        normalized.caseFold(data, len)
        normalized.trim()
        normalized.normalizeWhitespace()
        
        let (result, asize) = normalized.detachPtr()
        
        if result[0] == "\0" {
            return (nil, asize)
        }
        
        return (UnsafePointer(result), asize)
    }
}

extension CmarkReferenceMap {
    fileprivate func add(_ ref: CmarkReference) {
        var t = table[Int(ref.hash) % REFMAP_SIZE]
        ref.next = t
        
        while let theRef = t {
            if theRef.hash == ref.hash && strcmp(theRef.label!, ref.label!) == 0 {
                ref.free()
                return
            }
            
            t = theRef.next
        }
        
        table[Int(ref.hash) % REFMAP_SIZE] = ref
    }
    
    func create(label: CmarkChunk,
                url: CmarkChunk, title: CmarkChunk) {
        guard case let (label, asize) = label.normalizeReference(), let reflabel = label else {
            
            /* empty reference name, or composed from only whitespace */
            return
        }
        
        let ref = CmarkReference()
        ref.label = UnsafeMutablePointer(mutating: reflabel)
        ref.labelSize = asize
        ref.hash = refhash(reflabel)
        ref.url = url.cleanUrl()
        ref.title = title.cleanTitle()
        ref.next = nil
        
        add(ref)
    }
    
    // Returns reference if refmap contains a reference with matching
    // label, otherwise NULL.
    func lookup(
        _ label: CmarkChunk) -> CmarkReference? {
        var ref: CmarkReference? = nil
        
        if label.len < 1 || label.len > MAX_LINK_LABEL_LENGTH {
            return nil
        }
        
        guard case let (n, aSize) = label.normalizeReference(), let norm = n else {
            return nil
        }
        defer {
            if aSize > 0 {
                UnsafeMutablePointer(mutating: norm).deinitialize(count: aSize)
                UnsafeMutablePointer(mutating: norm).deallocate(capacity: aSize)
            }
        }
        
        let hash = refhash(norm)
        ref = table[Int(hash) % REFMAP_SIZE]
        
        while let theRef = ref {
            if theRef.hash == hash && strcmp(theRef.label!, norm) == 0 {
                break
            }
            ref = theRef.next
        }
        
        return ref
    }
    
    func free() {
        
        for i in 0..<REFMAP_SIZE {
            var ref = table[i]
            
            while ref != nil {
                let next = ref!.next
                ref!.free()
                ref = next
            }
        }
        
    }
    
}
