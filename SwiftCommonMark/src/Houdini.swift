//
//  Houdini.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/24.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on houdini.h, houdini_href_e.c, houdini_html_e.c and houdini_html_u.c
 https://github.com/commonmark/cmark/blob/master/src/houdini.h
 https://github.com/commonmark/cmark/blob/master/src/houdini_href_e.c
 https://github.com/commonmark/cmark/blob/master/src/houdini_html_e.c
 https://github.com/commonmark/cmark/blob/master/src/houdini_html_u.c
 */

import Foundation

//### When Switf's got __builtin_expect like feature, these definitions should be re-written.
func likely<T>(_ x: T)->T {return x}
func unlikely<T>(_ x: T)->T {return x}

/*
 * Helper _isdigit methods -- do not trust the current locale
 * */
extension UInt8 {
    var isXDigit: Bool {return "0" <= self && self <= "9" || "A" <= self && self <= "F" || "a" <= self && self <= "f"}
    //### Use `cmark_isdigit` or `isDigit` for locale-independent ctype functions.
    //#define _isdigit(c) ((c) >= '0' && (c) <= '9')
}
extension UnicodeScalar {
    var isXDigit: Bool {return self.value <= UInt8.max && UInt8(self.value).isXDigit}
}

//### Not used
//#define HOUDINI_ESCAPED_SIZE(x) (((x)*12) / 10)
func HOUDINI_UNESCAPED_SIZE(_ x: Int)-> Int {return x}

/*
 * The following characters will not be escaped:
 *
 *        -_.+!*'(),%#@?=;:/,+&$ alphanum
 *
 * Note that this character set is the addition of:
 *
 *    - The characters which are safe to be in an URL
 *    - The characters which are *not* safe to be in
 *    an URL because they are RESERVED characters.
 *
 * We asume (lazily) that any RESERVED char that
 * appears inside an URL is actually meant to
 * have its native function (i.e. as an URL
 * component/separator) and hence needs no escaping.
 *
 * There are two exceptions: the chacters & (amp)
 * and ' (single quote) do not appear in the table.
 * They are meant to appear in the URL as components,
 * yet they require special HTML-entity escaping
 * to generate valid HTML markup.
 *
 * All other characters will be escaped to %XX.
 *
 */
private let HREF_SAFE: [Int8] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1,
    0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
]
extension UnicodeScalar {
    var hrefSafe: Bool {
        return self.value <= 127 && HREF_SAFE[Int(self.value)] != 0
    }
    ///size in UTF-8
    var size: Int {
        return String(self).utf8.count
    }
}

extension StringBuffer {
    @discardableResult
    func escapeHref(_ src: StringChunk) -> Bool {
        let usv = src.string.unicodeScalars
        let endIndex = src.endIndex
        var i = src.startIndex
        
        while i < endIndex {
            let org = i
            while i < endIndex && src[i].hrefSafe {
                i = usv.index(after: i)
            }
            
            if likely(i > org) {
                put(src.string, org, i)
            }
            
            /* escaping */
            if i >= endIndex {
                break
            }
            
            for c in String(src[i]).utf8 {
                if HREF_SAFE[Int(c)] != 0 {
                    putc(c)
                } else {
                    switch src[i] {
                        /* amp appears all the time in URLs, but needs
                         * HTML-entity escaping to be inside an href */
                    case "&":
                        puts("&amp;")
                        
                        /* the single quote is a valid URL character
                         * according to the standard; it needs HTML
                         * entity escaping too */
                    case "'":
                        puts("&#x27;")
                        
                        /* the space can be escaped to %20 or a plus
                         * sign. we're going with the generic escape
                         * for now. the plus thing is more commonly seen
                         * when building GET strings */
                        //#if 0
                        //        case ' ':
                        //            cmark_strbuf_putc(ob, '+');
                        //            break;
                        //#endif
                        
                        /* every other character goes with a %XX escaping */
                    default:
                        puts(String(format: "%%%02X", c))
                    }
                }
            }
            i = usv.index(after: i)
        }
        
        return true
    }
}

/**
 * According to the OWASP rules:
 *
 * & --> &amp;
 * < --> &lt;
 * > --> &gt;
 * " --> &quot;
 * ' --> &#x27;     &apos; is not recommended
 * / --> &#x2F;     forward slash is included as it helps end an HTML entity
 *
 */
private let HTML_ESCAPE_TABLE: [Int] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 1, 0, 0, 0, 2, 3, 0, 0, 0, 0, 0, 0, 0, 4,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 6, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
]

private let HTML_ESCAPES: [String] = ["",      "&quot;", "&amp;", "&#39;",
                                      "&#47;", "&lt;",   "&gt;"]

extension StringBuffer {
    @discardableResult
    func escapeHtml0(_ string: String,
                     _ startIndex: String.UnicodeScalarIndex,
                     _ endIndex: String.UnicodeScalarIndex,
                     _ secure: Bool) -> Bool {
        var i = startIndex
        var esc = 0
        let usv = string.unicodeScalars
        
        while i < endIndex {
            let org = i
            while i < endIndex {
                esc = usv[i].value < 128 ? HTML_ESCAPE_TABLE[Int(usv[i].value)] : 0
                if esc != 0 {break}
                i = usv.index(after: i)
            }
            
            if i > org {
                put(string, org, i)
            }
            
            /* escaping */
            if unlikely(i >= endIndex) {
                break
            }
            
            /* The forward slash is only escaped in secure mode */
            if (usv[i] == "/" || usv[i] == "'") && !secure {
                put(usv[i])
            } else {
                puts(HTML_ESCAPES[esc])
            }
            
            i = usv.index(after: i)
        }
        
        return true
    }
}

//### Not used.
//int houdini_escape_html(cmark_strbuf *ob, const uint8_t *src, bufsize_t size) {
//  return houdini_escape_html0(ob, src, size, 1);
//}

/* Binary tree lookup code for entities added by JGM */

private func S_lookup<S:StringProtocol>(_ i: Int, _ low: Int, _ hi: Int,
                      _ s: S) -> String? {
    if s == cmark_entities[i].name {
        return cmark_entities[i].characters
    } else if s < cmark_entities[i].name && i > low {
        var j = i - ((i - low) / 2)
        if j == i {
            j -= 1
        }
        return S_lookup(j, low, i - 1, s)
    } else if s > cmark_entities[i].name && i < hi {
        var j = i + ((hi - i) / 2)
        if j == i {
            j += 1
        }
        return S_lookup(j, i + 1, hi, s)
    } else {
        return nil
    }
}

private func S_lookup_entity<S:StringProtocol>(_ s: S) -> String? {
    return S_lookup(CMARK_NUM_ENTITIES / 2, 0, CMARK_NUM_ENTITIES - 1, s)
}

extension StringBuffer {
    ///returns: UTF-8 size of written entity
    @discardableResult
    func unescapedEnt(_ string: String, _ start: String.Index, _ _end: String.Index) -> Int {
        var end = _end
        var i = start
        let usv = string.unicodeScalars
        
        if usv.distance(from: start, to: end) >= 3 && usv[start] == "#" {
            var codepoint: Int32 = 0
            var numDigits = 0
            let i1 = usv.index(after: start)
            let i2 = usv.index(after: i1)

            if usv[i1].isDigit {
                i = i1
                while i < end && usv[i].isDigit {
                    codepoint = codepoint * 10 + Int32(usv[i].value) - "0"
                    
                    if codepoint >= 0x11_0000 {
                        // Keep counting digits but
                        // avoid integer overflow.
                        codepoint = 0x11_0000
                    }
                    i = usv.index(after: i)
                }
                
                numDigits = usv.distance(from: start, to: i) - 1
                
            } else if usv[i1] == "x" || usv[i1] == "X" {
                i = i2
                while i < end && usv[i].isXDigit {
                    codepoint = codepoint * 16 + Int32((usv[i].value | 32) % 39 - 9)
                    
                    if codepoint >= 0x11_0000 {
                        // Keep counting digits but
                        // avoid integer overflow.
                        codepoint = 0x11_0000
                    }
                    i = usv.index(after: i)
                }
                
                numDigits = usv.distance(from: start, to: i) - 2
            }
            
            if numDigits >= 1 && numDigits <= 8 && i < end && usv[i] == ";" {
                if codepoint == 0 || (codepoint >= 0xD800 && codepoint < 0xE000) ||
                    codepoint >= 0x11_0000 {
                    codepoint = 0xFFFD
                }
                encodeChar(codepoint)
                return string.utf8.distance(from: start, to: i) + 1
            }
            
        } else {
            if usv.distance(from: start, to: end) > CMARK_ENTITY_MAX_LENGTH {
                end = usv.index(start, offsetBy: CMARK_ENTITY_MAX_LENGTH)
            }
            
            i = usv.index(start, offsetBy: CMARK_ENTITY_MIN_LENGTH)
            while i < end {
                if usv[i] == " " {
                    break
                }
                
                if usv[i] == ";" {
                    let entityName = String(string[start..<i])
                    if let entity = S_lookup_entity(entityName) {
                        
                        self.puts(entity)
                        return string.utf8.distance(from: start, to: i) + 1
                    }
                    
                    break
                }
                
                i = string.unicodeScalars.index(after: i)
            }
        }
        
        return 0
    }
    
    @discardableResult
    func unescapeHtml(_ string: String, _ start: String.Index, _ end: String.Index) -> Bool {
        var i = start
        let usv = string.unicodeScalars
        
        while i < end {
            let org = i
            while i < end && usv[i] != "&" {
                i = usv.index(after: i)
            }
            
            if likely(i > org) {
                if unlikely(org == start) {
                    if i >= end {
                        return false
                    }
                }
                
                put(string, org, i)
            }
            
            /* escaping */
            if i >= end {
                break
            }
            
            i = usv.index(after: i)

            let ent = unescapedEnt(string, i, end)
            i = string.utf8.index(i, offsetBy: ent)
            
            /* not really an entity */
            if ent == 0 {
                putc("&")
            }
        }
        
        return true
    }
    @discardableResult
    func unescapeHtml(_ chunk: StringBufferType) -> Bool {
        return unescapeHtml(chunk.string, chunk.startIndex, chunk.endIndex)
    }
    
    func unescapeHtmlF(_ chunk: StringBufferType) {
        if !unescapeHtml(chunk) {
            put(chunk)
        }
    }
    func unescapeHtmlF(_ string: String, _ start: String.Index, _ end: String.Index) {
        if !unescapeHtml(string, start, end) {
            put(string, start, end)
        }
    }
}
