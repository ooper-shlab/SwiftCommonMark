//
//  Parser.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/17.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on parser.h
 https://github.com/commonmark/cmark/blob/master/src/parser.h
 
 Some comments moved from cmark.h
 https://github.com/commonmark/cmark/blob/master/src/cmark.h
 */

import Foundation

let  MAX_LINK_LABEL_LENGTH = 1000

/**
 * ## Parsing
 *
 * Simple interface:
 *
 *     cmark_node *document = cmark_parse_document("Hello *world*", 13,
 *                                                 CMARK_OPT_DEFAULT);
 *
 * Streaming interface:
 *
 *     cmark_parser *parser = cmark_parser_new(CMARK_OPT_DEFAULT);
 *     FILE *fp = fopen("myfile.md", "rb");
 *     while ((bytes = fread(buffer, 1, sizeof(buffer), fp)) > 0) {
 *            cmark_parser_feed(parser, buffer, bytes);
 *            if (bytes < sizeof(buffer)) {
 *                break;
 *            }
 *     }
 *     document = cmark_parser_finish(parser);
 *     cmark_parser_free(parser);
 */

public class CmarkParser {
    var refmap: CmarkReferenceMap = CmarkReferenceMap()
    let root: CmarkNode
    var current: CmarkNode?
    var lineNumber: Int = 0
    var offset: Int = 0
    var column: Int = 0
    var firstNonspace: Int = 0
    var firstNonspaceColumn: Int = 0
    var indent: Int = 0
    var blank: Bool = false
    var partiallyConsumedTab: Bool = false
    let curline: StringBuffer = StringBuffer(capacity: 256)
    var lastLineLength: Int = 0
    let linebuf: StringBuffer = StringBuffer(capacity: 0)
    let options: CmarkOptions
    var lastBufferEndedWithCr: Bool = false
    
    /** Creates a new parser object with the given memory allocator
     */
    init(root: CmarkNode, options: CmarkOptions) {
        self.root = root
        self.current = root
        self.options = options
    }
}


