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
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1,
    0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
]

extension CmarkStrbuf {
    @discardableResult
    func escapeHref(_ src: UnsafePointer<UInt8>, _ size: Int) -> Bool {
        var i = 0
        
        while i < size {
            let org = i
            while i < size && HREF_SAFE[Int(src[i])] != 0 {
                i += 1
            }
            
            if likely(i > org) {
                put(src + org, i - org)
            }
            
            /* escaping */
            if i >= size {
                break
            }
            
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
                puts(String(format: "%%%02X", src[i]))
            }
            i += 1
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
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 2, 3, 0, 0, 0, 0, 0, 0, 0, 4,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
]

private let HTML_ESCAPES: [String] = ["",      "&quot;", "&amp;", "&#39;",
                                      "&#47;", "&lt;",   "&gt;"]

extension CmarkStrbuf {
    @discardableResult
    func escapeHtml0(_ src: UnsafePointer<UInt8>, _ size: Int,
                     _ secure: Bool) -> Bool {
        var i = 0, esc = 0
        
        while i < size {
            let org = i
            while i < size {
                esc = HTML_ESCAPE_TABLE[Int(src[i])]
                guard esc == 0 else {break}
                i += 1
            }
            
            if i > org {
                put(src + org, i - org)
            }
            
            /* escaping */
            if unlikely( i >= size) {
                break
            }
            
            /* The forward slash is only escaped in secure mode */
            if (src[i] == "/" || src[i] == "'") && !secure {
                putc(src[i])
            } else {
                puts(HTML_ESCAPES[esc])
            }
            
            i += 1
        }
        
        return true
    }
}

//### Not used.
//int houdini_escape_html(cmark_strbuf *ob, const uint8_t *src, bufsize_t size) {
//  return houdini_escape_html0(ob, src, size, 1);
//}

/* Binary tree lookup code for entities added by JGM */

private func S_lookup(_ i: Int, _ low: Int, _ hi: Int,
                      _ s: UnsafePointer<UInt8>, _ len: Int) -> String? {
    let cs = UnsafeRawPointer(s).assumingMemoryBound(to: CChar.self)
    let cmp =
        strncmp(cs, cmark_entities[i].name, len)
    if cmp == 0 && cmark_entities[i].name.utf8.count == len {
        return cmark_entities[i].characters
    } else if cmp <= 0 && i > low {
        var j = i - ((i - low) / 2)
        if j == i {
            j -= 1
        }
        return S_lookup(j, low, i - 1, s, len)
    } else if cmp > 0 && i < hi {
        var j = i + ((hi - i) / 2)
        if j == i {
            j += 1
        }
        return S_lookup(j, i + 1, hi, s, len)
    } else {
        return nil
    }
}

private func S_lookup_entity(_ s: UnsafePointer<UInt8>, _ len: Int) -> String? {
    return S_lookup(CMARK_NUM_ENTITIES / 2, 0, CMARK_NUM_ENTITIES - 1, s, len)
}

extension CmarkStrbuf {
    @discardableResult
    func unescapedEnt(_ src: UnsafePointer<UInt8>,
                      _ _size: Int) -> Int {
        var size = _size
        var i = 0
        
        if size >= 3 && src[0] == "#" {
            var codepoint: Int32 = 0
            var numDigits = 0
            
            if src[1].isDigit {
                i = 1
                while i < size && src[i].isDigit {
                    codepoint = codepoint * 10 + Int32(src[i] - "0")
                    
                    if codepoint >= 0x11_0000 {
                        // Keep counting digits but
                        // avoid integer overflow.
                        codepoint = 0x11_0000
                    }
                    i += 1
                }
                
                numDigits = i - 1
                
            } else if src[1] == "x" || src[1] == "X" {
                i = 2
                while i < size && src[i].isXDigit {
                    codepoint = codepoint * 16 + Int32((src[i] | 32) % 39 - 9)
                    
                    if codepoint >= 0x11_0000 {
                        // Keep counting digits but
                        // avoid integer overflow.
                        codepoint = 0x11_0000
                    }
                    i += 1
                }
                
                numDigits = i - 2
            }
            
            if numDigits >= 1 && numDigits <= 8 && i < size && src[i] == ";" {
                if codepoint == 0 || (codepoint >= 0xD800 && codepoint < 0xE000) ||
                    codepoint >= 0x11_0000 {
                    codepoint = 0xFFFD
                }
                encodeChar(codepoint)
                return i + 1
            }
            
        } else {
            if size > CMARK_ENTITY_MAX_LENGTH {
                size = CMARK_ENTITY_MAX_LENGTH
            }
            
            for i in CMARK_ENTITY_MIN_LENGTH..<size {
                if src[i] == " " {
                    break
                }
                
                if src[i] == ";" {
                    if let entity = S_lookup_entity(src, i) {
                        
                        self.puts(entity)
                        return i + 1
                    }
                    
                    break
                }
            }
        }
        
        return 0
    }
    
    @discardableResult
    func unescapeHtml(_ src: UnsafePointer<UInt8>,
                      _ size: Int) -> Bool {
        var i = 0
        
        while i < size {
            let org = i
            while i < size && src[i] != "&" {
                i += 1
            }
            
            if likely(i > org) {
                if unlikely(org == 0) {
                    if i >= size {
                        return false
                    }
                    
                    grow(to: HOUDINI_UNESCAPED_SIZE(size))
                }
                
                put(src + org, i - org)
            }
            
            /* escaping */
            if i >= size {
                break
            }
            
            i += 1
            
            let ent = unescapedEnt(src + i, size - 1)
            i += ent
            
            /* not really an entity */
            if ent == 0 {
                putc("&")
            }
        }
        
        return true
    }
    @discardableResult
    public func unescapeHtml(_ chunk: CmarkChunk) -> Bool {
        return unescapeHtml(chunk.data, chunk.len)
    }
    
    func unescapeHtmlF(_ src: UnsafePointer<UInt8>,
                       _ size: Int) {
        if !unescapeHtml(src, size) {
            put(src, size)
        }
    }
}
