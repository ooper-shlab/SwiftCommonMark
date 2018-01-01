//
//  Cmark.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/17.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on cmark.c and cmark.h
 https://github.com/commonmark/cmark/blob/master/src/cmark.c
 https://github.com/commonmark/cmark/blob/master/src/cmark.h
 */

import Foundation

/** # NAME
 *
 * **cmark** - CommonMark parsing, manipulating, and rendering
 */

/** # DESCRIPTION
 *
 * ## Simple Interface
 */

/** ## Node Structure
 */

public enum CmarkNodeType: UInt32 {
    /* Error status */
    case none
    
    /* Block */
    case document
    case blockQuote
    case list
    case item
    case codeBlock
    case htmlBlock
    case customBlock
    case paragraph
    case heading
    case thematicBreak
    
    static let firstBlock: CmarkNodeType = .document
    static let lastBlock: CmarkNodeType = .thematicBreak
    
    public var isBlock: Bool {
        return CmarkNodeType.firstBlock.rawValue <= rawValue && rawValue <= CmarkNodeType.lastBlock.rawValue
    }
    
    /* Inline */
    case text
    case softbreak
    case linebreak
    case code
    case htmlInline
    case customInline
    case emph
    case strong
    case link
    case image
    
    static let firstInline: CmarkNodeType = .text
    static let lastInline: CmarkNodeType = .image
    
    public var isInline: Bool {
        return CmarkNodeType.firstInline.rawValue <= rawValue && rawValue <= CmarkNodeType.lastInline.rawValue
    }
}

//### Compatibility features seem not to be needed...
///* For backwards compatibility: */
//public extension CmarkNodeType {
//    public static let header: CmarkNodeType = .heading
//    public static let hrule: CmarkNodeType = .thematicBreak
//    public static let html: CmarkNodeType = .htmlBlock
//    public static let inlineHtml: CmarkNodeType = .htmlInline
//}

public enum CmarkListType {
    case noList
    case bulletList
    case orderedList
}

public enum CmarkDelimType {
    case noDelim
    case periodDelim
    case parenDelim
}

//### Compatibility features seem not to be needed...
///* For backwards compatibility */
//#define cmark_node_get_header_level cmark_node_get_heading_level
//#define cmark_node_set_header_level cmark_node_set_heading_level

/**
 * ## Options
 */
public struct CmarkOptions: OptionSet {
    public var rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    init(_ rawValue: Int) {
        self.rawValue = rawValue
    }
    
    /** Default options.
     */
    static let `default` = CmarkOptions(0)
    
    /**
     * ### Options affecting rendering
     */
    
    /** Include a `data-sourcepos` attribute on all block elements.
     */
    static let sourcepos = CmarkOptions(1 << 1)
    
    /** Render `softbreak` elements as hard line breaks.
     */
    static let hardbreaks = CmarkOptions(1 << 2)
    
    /** Suppress raw HTML and unsafe links (`javascript:`, `vbscript:`,
     * `file:`, and `data:`, except for `image/png`, `image/gif`,
     * `image/jpeg`, or `image/webp` mime types).  Raw HTML is replaced
     * by a placeholder HTML comment. Unsafe links are replaced by
     * empty strings.
     */
    static let safe = CmarkOptions(1 << 3)
    
    /** Render `softbreak` elements as spaces.
     */
    static let nobreaks = CmarkOptions(1 << 4)
    
    /**
     * ### Options affecting parsing
     */
    
    /** Legacy option (no effect).
     */
    static let normalize = CmarkOptions(1 << 8)
    
    /** Validate UTF-8 in the input before parsing, replacing illegal
     * sequences with the replacement character U+FFFD.
     */
    static let validateUTF8 = CmarkOptions(1 << 9)
    
    /** Convert straight quotes to curly, --- to em dashes, -- to en dashes.
     */
    static let smart = CmarkOptions(1 << 10)
}

//### Authors of the original C-version of cmark
/** # AUTHORS
 *
 * John MacFarlane, Vicent Marti,  Kārlis Gaņģis, Nick Wellnhofer.
 */

/**
 * ## Version information
 */

/** The library version as integer for runtime checks. Also available as
 * macro CMARK_VERSION for compile time checks.
 *
 * * Bits 16-23 contain the major version.
 * * Bits 8-15 contain the minor version.
 * * Bits 0-7 contain the patchlevel.
 *
 * In hexadecimal format, the number 0x010203 represents version 1.2.3.
 */
public func cmark_version() -> Int32 {return CMARK_VERSION}

/** The library version string for runtime checks. Also available as
 * macro CMARK_VERSION_STRING for compile time checks.
 */
public func cmark_version_string() -> String {return CMARK_VERSION_STRING}
//
//static void *xcalloc(size_t nmem, size_t size) {
//  void *ptr = calloc(nmem, size);
//  if (!ptr) {
//    fprintf(stderr, "[cmark] calloc returned null pointer, aborting\n");
//    abort();
//  }
//  return ptr;
//}
//
//static void *xrealloc(void *ptr, size_t size) {
//  void *new_ptr = realloc(ptr, size);
//  if (!new_ptr) {
//    fprintf(stderr, "[cmark] realloc returned null pointer, aborting\n");
//    abort();
//  }
//  return new_ptr;
//}
//
//cmark_mem DEFAULT_MEM_ALLOCATOR = {xcalloc, xrealloc, free};

/** Convert 'text' (assumed to be a UTF-8 encoded string with length
 * 'len') from CommonMark Markdown to HTML, returning a null-terminated,
 * UTF-8-encoded string. It is the caller's responsibility
 * to free the returned buffer.
 */
public func cmark_markdown_to_html(_ text: String, _ options: CmarkOptions) -> String {
    
    let doc = cmark_parse_document(text, options)
    
    let result = doc.renderHtml(options)
    doc.free()
    
    return result
}
public func cmark_markdown_to_html(_ data: Data, _ options: CmarkOptions) -> String {
    
    let doc = cmark_parse_document(data, options)
    
    let result = doc.renderHtml(options)
    doc.free()
    
    return result
}
