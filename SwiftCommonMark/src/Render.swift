//
//  Render.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/16.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on render.c and render.h
 https://github.com/commonmark/cmark/blob/master/src/render.h
 https://github.com/commonmark/cmark/blob/master/src/render.h
 
 Some comments moved from cmark.h
 https://github.com/commonmark/cmark/blob/master/src/cmark.h
 */

import Foundation

/**
 * ## Rendering
 */

enum CmarkEscaping {
    case literal
    case normal
    case title
    case url
}

class CmarkRenderer {
    let buffer: CmarkStrbuf
    let prefix: CmarkStrbuf
    var column: Int
    let width: Int
    var needCr: Int = 0
    var lastBreakable: Int
    var beginLine: Bool
    var beginContent: Bool
    var noLinebreaks: Bool
    var inTightListItem: Bool
    let outc: (CmarkRenderer, CmarkEscaping, Int32, UInt8)->Void
    let cr: (CmarkRenderer)->Void
    let blankline: (CmarkRenderer)->Void
    let out: (CmarkRenderer, UnsafePointer<CChar>, Bool, CmarkEscaping)->Void
    
    init(_ buffer: CmarkStrbuf, _ prefix: CmarkStrbuf, _ column: Int, _ width: Int, _ needCr: Int,
         _ lastBreakable: Int, _ beginLine: Bool, _ beginContent: Bool, _ noLinebreaks: Bool,
         _ inTightListItem: Bool,
         _ outc: @escaping (CmarkRenderer, CmarkEscaping, Int32, UInt8)->Void,
         _ cr: @escaping (CmarkRenderer)->Void,
         _ blankline: @escaping (CmarkRenderer)->Void,
         _ out: @escaping (CmarkRenderer, UnsafePointer<CChar>, Bool, CmarkEscaping)->Void
        ) {
        self.buffer = buffer
        self.prefix = prefix
        self.column = column
        self.width = width
        self.needCr = needCr
        self.lastBreakable = lastBreakable
        self.beginLine = beginLine
        self.beginContent = beginContent
        self.noLinebreaks = noLinebreaks
        self.inTightListItem = inTightListItem
        self.outc = outc
        self.cr = cr
        self.blankline = blankline
        self.out = out
    }
}

private func S_cr(_ renderer: CmarkRenderer) {
    if renderer.needCr < 1 {
        renderer.needCr = 1
    }
}

private func S_blankline(_ renderer: CmarkRenderer) {
    if renderer.needCr < 2 {
        renderer.needCr = 2
    }
}

private func S_out(_ renderer: CmarkRenderer, _ source: UnsafePointer<CChar>, _ _wrap: Bool,
                   _ escape: CmarkEscaping) {
    let length = strlen(source)
    var i = 0;
    let remainder = CmarkChunk(literal: "")
    var k = renderer.buffer.size - 1
    
    let wrap = _wrap && !renderer.noLinebreaks
    
    if renderer.inTightListItem && renderer.needCr > 1 {
        renderer.needCr = 1
    }
    while renderer.needCr > 0 {
        if k < 0 || renderer.buffer.ptr[k] == "\n" {
            k -= 1
        } else {
            renderer.buffer.putc("\n")
            if renderer.needCr > 1 {
                renderer.buffer.put(renderer.prefix)
            }
        }
        renderer.column = 0
        renderer.beginLine = true
        renderer.beginContent = true
        renderer.needCr -= 1
    }
    
    while i < length {
        if renderer.beginLine {
            renderer.buffer.put(renderer.prefix)
            // note: this assumes prefix is ascii:
            renderer.column = renderer.prefix.size
        }
        
        var c: Int32 = 0
        let ucsource = UnsafeRawPointer(source).assumingMemoryBound(to: UInt8.self)
        let len = cmark_utf8proc_iterate(ucsource + i, length - i, &c)
        if len == -1 { // error condition
            return        // return without rendering rest of string
        }
        let nextc = ucsource[i + len]
        if c == 32 && wrap {
            if !renderer.beginLine {
                let lastNonspace = renderer.buffer.size
                renderer.buffer.putc(" ")
                renderer.column += 1
                renderer.beginLine = false
                renderer.beginContent = false
                // skip following spaces
                while ucsource[i + 1] == " " {
                    i += 1
                }
                // We don't allow breaks that make a digit the first character
                // because this causes problems with commonmark output.
                if !cmark_isdigit(Int32(source[i + 1])) {
                    renderer.lastBreakable = lastNonspace
                }
            }
            
        } else if c == 10 {
            renderer.buffer.putc("\n")
            renderer.column = 0
            renderer.beginLine = true
            renderer.beginContent = true
            renderer.lastBreakable = 0
        } else if escape == .literal {
            renderer.renderCodePoint(c)
            renderer.beginLine = false
            // we don't set 'begin_content' to false til we've
            // finished parsing a digit.  Reason:  in commonmark
            // we need to escape a potential list marker after
            // a digit:
            renderer.beginContent = renderer.beginContent && cmark_isdigit(c)
        } else {
            renderer.outc(renderer, escape, c, nextc)
            renderer.beginLine = false
            renderer.beginContent =
                renderer.beginContent && cmark_isdigit(c)
        }
        
        // If adding the character went beyond width, look for an
        // earlier place where the line could be broken:
        if renderer.width > 0 && renderer.column > renderer.width &&
            !renderer.beginLine && renderer.lastBreakable > 0 {
            
            // copy from last_breakable to remainder
            let ptr = UnsafeRawPointer(renderer.buffer.ptr).assumingMemoryBound(to: CChar.self)
            remainder.setCstr(ptr + renderer.lastBreakable + 1)
            // truncate at last_breakable
            renderer.buffer.truncate(renderer.lastBreakable)
            // add newline, prefix, and remainder
            renderer.buffer.putc("\n")
            renderer.buffer.put(renderer.prefix)
            renderer.buffer.put(remainder)
            renderer.column = renderer.prefix.size + remainder.len
            remainder.free()
            renderer.lastBreakable = 0
            renderer.beginLine = false
            renderer.beginContent = false
        }
        
        i += len
    }
}

extension CmarkRenderer {
    // Assumes no newlines, assumes ascii content:
    func renderAscii(_ s: UnsafePointer<CChar>) {
        let origsize = buffer.size
        buffer.puts(s)
        column += buffer.size - origsize
    }
    
    func renderCodePoint(_ c: Int32) {
        buffer.encodeChar(c)
        column += 1
    }
}

extension CmarkNode {
    func render(_ options: CmarkOptions, _ width: Int,
                _ outc: @escaping (CmarkRenderer, CmarkEscaping, Int32, UInt8)->Void,
                _ renderNode: (CmarkRenderer, CmarkNode, CmarkEventType, CmarkOptions)->Int) -> String {
        let pref = CmarkStrbuf()
        let buf = CmarkStrbuf()
        let iter = CmarkIter(self)
        
        let renderer = CmarkRenderer(buf, pref, 0, width,
                                     0, 0, true, true, false, false,
                                     outc, S_cr, S_blankline, S_out)
        
        while case let evType = iter.next(), evType != .done {
            let cur = iter.getNode()!
            if renderNode(renderer, cur, evType, options) == 0 {
                // a false value causes us to skip processing
                // the node's contents.  this is used for
                // autolinks.
                iter.reset(cur, .exit)
            }
        }
        
        // ensure final newline
        if renderer.buffer.ptr[renderer.buffer.size - 1] != "\n" {
            renderer.buffer.putc("\n")
        }
        
        let result = renderer.buffer.detach()
        
        iter.free()
        renderer.prefix.free()
        renderer.buffer.free()
        
        return result
    }
}
