//
//  Blocks.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/17.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on blocks.c
 https://github.com/commonmark/cmark/blob/master/src/blocks.c
 
 Some comments moved from cmark.h
 https://github.com/commonmark/cmark/blob/master/src/cmark.h
 */

import Foundation
/**
 * Block parsing implementation.
 *
 * For a high-level overview of the block parsing process,
 * see http://spec.commonmark.org/0.24/#phase-1-block-structure
 */

let CODE_INDENT = 4
let TAB_STOP = 4

//extension StringChunk {
//    ///### n: valid UTF-8 offset from startIndex
//    func peek(at n: Int) -> UnicodeScalar {return self[n]}
//}

extension CmarkNode {
    fileprivate var isLastLineBlank: Bool {
        return flags.contains(.lastLineBlank)
    }
    
    fileprivate func setLastLineBlank(_ isBlank: Bool) {
        if isBlank {
            flags.formUnion(.lastLineBlank)
        } else {
            flags.subtract(.lastLineBlank)
        }
    }
}

extension UInt8 {
    var isSpaceOrTab: Bool {
        return self == " " || self == "\t"
    }
}

extension UnicodeScalar {
    var isLineEnd: Bool {
        return self == "\n" || self == "\r"
    }
    
    var isSpaceOrTab: Bool {
        return self == " " || self == "\t"
    }
}

extension CmarkNode {
    fileprivate convenience init(tag: CmarkNodeType, startLine: Int, startColumn: Int) {
        
        self.init(tag: tag, content: StringBuffer(capacity: 32), flags: .open)
        self.startLine = startLine
        self.startColumn = startColumn
        self.endLine = startLine
        
    }
}

// Create a root document node.
private func makeDocument() -> CmarkNode {
    let e = CmarkNode(tag: .document, startLine: 1, startColumn: 1)
    return e
}

extension CmarkParser {
    
    /** Creates a new parser object.
     */
    public convenience init(options: CmarkOptions) {
        
        let document = makeDocument()
        self.init(root: document, options: options)
        
    }
    
    /** Frees memory allocated for a parser object.
     */
    public func free() {
        curline.free()
        linebuf.free()
        refmap.free()
    }
    
}

extension StringBuffer {
    // Returns true if line has only space characters, else false.
    fileprivate func isBlank(_ offset: Int) -> Bool {
        var index = self.index(startIndex, offsetBy: offset)
        let usv = string.unicodeScalars
        while index < endIndex {
            switch usv[index] {
            case "\r", "\n":
                return true
            case " ", "\t":
                index = usv.index(after: index)
            default:
                return false
            }
        }
        
        return true
    }
}

extension CmarkNodeType {
    fileprivate func canContain(
        _ childType: CmarkNodeType) -> Bool {
        return self == .document ||
            self == .blockQuote ||
            self == .item ||
            (self == .list && childType == .item)
    }
    
    fileprivate var acceptsLines: Bool {
        return self == .paragraph ||
            self == .heading ||
            self == .codeBlock
    }
    
    fileprivate var containsInlines: Bool {
        return self == .paragraph ||
            self == .heading
    }
}

extension CmarkParser {
    fileprivate func add(to node: CmarkNode, line ch: StringChunk) {
        assert(node.flags.contains(.open))
        if partiallyConsumedTab {
            parseIndex = ch.index(after: parseIndex) // skip over tab
            // add space characters:
            let charsToTab = TAB_STOP - (column % TAB_STOP)
            for _ in 0..<charsToTab {
                node.content.putc(" ")
            }
        }
        node.content.put(ch, parseIndex)
    }
}

extension StringBuffer {
    fileprivate func removeTrailingBlankLines() {
        
        var i = endIndex
        let usv = string.unicodeScalars
        while i > startIndex {
            i = usv.index(before: i)
            let c = usv[i]
            
            if c != " " && c != "\t" && !c.isLineEnd {
                break
            }
        }
        
        if i == startIndex {
            clear()
            return
        }
        
        while i < endIndex {
            let c = usv[i]
            
            if c.isLineEnd {
                truncate(i)
            }
            
            i = usv.index(after: i)
        }
    }
}

extension CmarkNode {
    // Check to see if a node ends with a blank line, descending
    // if needed into lists and sublists.
    fileprivate func endsWithBlankLine() -> Bool {
        var cur: CmarkNode? = self
        while let curNode = cur {
            if curNode.isLastLineBlank {
                return true
            }
            if curNode.type == .list || curNode.type == .item {
                cur = curNode.lastChild
            } else {
                cur = nil
            }
        }
        return false
    }
}

extension CmarkParser {
    func finalize(_ b: CmarkNode) -> CmarkNode? {
        
        let parent = b.parent
        assert(b.flags.contains(.open)) // shouldn't call finalize on closed blocks
        b.flags.remove(.open)
        
        if curline.size == 0 {
            // end of input - line number has not been incremented
            b.endLine = lineNumber
            b.endColumn = lastLineLength
        } else if b.type == .document ||
            (b.type == .codeBlock && b.asCode?.fenced ?? false) ||
            (b.type == .heading && b.asHeading?.setext ?? false) {
            b.endLine = lineNumber
            b.endColumn = curline.size
            if b.endColumn != 0 && curline[b.endColumn - 1] == "\n" {
                b.endColumn -= 1
            }
            if b.endColumn != 0 && curline[b.endColumn - 1] == "\r" {
                b.endColumn -= 1
            }
        } else {
            b.endLine = lineNumber - 1
            b.endColumn = lastLineLength
        }
        
        let nodeContent = b.content
        
        switch b.type {
        case .paragraph:
            let chunk = StringChunk(content: nodeContent)
            while !chunk.isEmpty && chunk.first! == "[",
                let index = chunk.parseReferenceInline(refmap) {
                    chunk.start(from: index)
            }
            nodeContent.drop(nodeContent.size - chunk.len)
            if nodeContent.isBlank(0) {
                // remove blank node (former reference def)
                b.free()
            }
            
        case .codeBlock:
            if !(b.asCode?.fenced ?? false) { // indented code
                nodeContent.removeTrailingBlankLines()
                nodeContent.putc("\n")
            } else {
                // first line of contents becomes info
                var pos = nodeContent.startIndex
                let usv = nodeContent.string.unicodeScalars
                while pos < nodeContent.endIndex {
                    if nodeContent[pos].isLineEnd {
                        break
                    }
                    
                    pos = usv.index(after: pos)
                }
                assert(pos < nodeContent.endIndex)
                
                let tmp = StringBuffer()
                tmp.unescapeHtmlF(nodeContent.string, nodeContent.startIndex, pos)
                tmp.trim()
                tmp.unescape()
                var code = b.asCode ?? CmarkCode()
                code.info = tmp.bufDetach()
                b.asType = .code(code)
                
                if nodeContent[pos] == "\r" {
                    pos = usv.index(after: pos)
                }
                if nodeContent[pos] == "\n" {
                    pos = usv.index(after: pos)
                }
                nodeContent.start(from: pos)
                
            }
            var code = b.asCode ?? CmarkCode()
            code.literal = nodeContent.bufDetach()
            b.asType = .code(code)
            
        case .htmlBlock:
            b.asType = .literal(nodeContent.bufDetach())
            
        case .list:
            var list = b.asList ?? CmarkList()
            list.tight = true
            b.asType = .list(list)
            var item = b.firstChild
            
            while let theItem = item {
                // check for non-final non-empty list item ending with blank line:
                if theItem.isLastLineBlank && theItem.next != nil {
                    var list = b.asList ?? CmarkList()
                    list.tight = false
                    b.asType = .list(list)
                }
                // recurse into children of list item, to see if there are
                // spaces between them:
                var subitem = item?.firstChild
                while let theSubitem = subitem {
                    if theSubitem.endsWithBlankLine() && (theItem.next != nil || theSubitem.next != nil) {
                        var list = b.asList ?? CmarkList()
                        list.tight = false
                        b.asType = .list(list)
                        break
                    }
                    subitem = theSubitem.next
                }
                if !(b.asList?.tight ?? false) {
                    break
                }
                item = theItem.next
            }
            
        default:
            break
        }
        
        return parent
    }
    
    // Add a node as child of another.  Return pointer to child.
    func addChild(parent _parent: CmarkNode,
                  blockType: CmarkNodeType, startColumn: Int) -> CmarkNode {
        var parent = _parent
        
        // if 'parent' isn't the kind of node that can accept this child,
        // then back up til we hit a node that can.
        while !parent.type.canContain(blockType) {
            parent = finalize(parent)!
        }
        
        let child =
            CmarkNode(tag: blockType, startLine: lineNumber, startColumn: startColumn)
        child.parent = parent
        
        if let lastChild = parent.lastChild {
            lastChild.next = child
            child.prev = lastChild
        } else {
            parent.firstChild = child
            child.prev = nil
        }
        parent.lastChild = child
        return child
    }
}

extension CmarkNode {
    // Walk through node and all children, recursively, parsing
    // string content into inline content where appropriate.
    fileprivate func processInlines(_ refmap: CmarkReferenceMap, _ options: CmarkOptions) {
        let iter = CmarkIter(self)
        
        while case let evType = iter.next(), evType != .done {
            let cur = iter.getNode()
            if evType == .enter {
                if let cur = cur, cur.type.containsInlines {
                    cur.parseInlines(refmap, options)
                }
            }
        }
        
        iter.free()
    }
}

extension StringChunk {
    // Attempts to parse a list item marker (bullet or enumerated).
    // On success, returns length of the marker, and populates
    // data with the details.  On failure, returns 0.
    fileprivate func parseListMarker(
        index _index: String.Index, interruptsParagraph: Bool,
        dataptr: inout CmarkList?) -> Int {
        var ix = _index
        var data: CmarkList? = nil
        
        let startIndex = ix
        var c = self[ix]
        
        if c == "*" || c == "-" || c == "+" {
            ix = index(after: ix)
            if !self[ix].isSpace {
                return 0
            }
            
            if interruptsParagraph {
                var i = ix
                // require non-blank content after list marker:
                while self[i].isSpaceOrTab {
                    i = index(after: i)
                }
                if self[i] == "\n" {
                    return 0
                }
            }
            
            data = CmarkList()
            data?.markerOffset = 0 // will be adjusted later
            data?.listType = .bulletList
            data?.bulletChar = c
            data?.start = 0
            data?.delimiter = .noDelim
            data?.tight = false
        } else if c.isDigit {
            var start = 0
            var digits = 0
            
            repeat {
                start = 10 * start + Int(UInt8(self[ix].value) - "0")
                ix = index(after: ix)
                digits += 1
                // We limit to 9 digits to avoid overflow,
                // assuming max int is 2^31 - 1
                // This also seems to be the limit for 'start' in some browsers.
            } while digits < 9 && self[ix].isDigit
            
            if interruptsParagraph && start != 1 {
                return 0
            }
            c = self[ix]
            if c == "." || c == ")" {
                ix = index(after: ix)
                if !self[ix].isSpace {
                    return 0
                }
                if interruptsParagraph {
                    // require non-blank content after list marker:
                    var i = ix
                    while self[i].isSpaceOrTab {
                        i = index(after: i)
                    }
                    if self[i].isLineEnd {
                        return 0
                    }
                }
                
                data = CmarkList()
                data?.markerOffset = 0 // will be adjusted later
                data?.listType = .orderedList
                data?.bulletChar = "\0"
                data?.start = start
                data?.delimiter = c == "." ? .periodDelim : .parenDelim
                data?.tight = false
            } else {
                return 0
            }
        } else {
            return 0
        }
        
        dataptr = data
        return distance(from: startIndex, to: ix)
    }
}

extension CmarkList {
    // Return 1 if list item belongs in list, else 0.
    fileprivate func doesMatch(_ itemData: CmarkList) -> Bool {
        return self.listType == itemData.listType &&
            self.delimiter == itemData.delimiter &&
            // list_data->marker_offset == item_data.marker_offset &&
            self.bulletChar == itemData.bulletChar
    }
}

extension CmarkParser {
    @discardableResult
    private func finalizeDocument() -> CmarkNode {
        while current !== root {
            current = finalize(current!)
        }
        
        _ = finalize(root)
        root.processInlines(refmap, options)
        
        return root
    }
}
//
///** Parse a CommonMark document in file 'f', returning a pointer to
// * a tree of nodes.  The memory allocated for the node tree should be
// * released using 'cmark_node_free' when it is no longer needed.
// */
//cmark_node *cmark_parse_file(FILE *f, int options) {
//  unsigned char buffer[4096];
//  cmark_parser *parser = cmark_parser_new(options);
//  size_t bytes;
//  cmark_node *document;
//
//  while ((bytes = fread(buffer, 1, sizeof(buffer), f)) > 0) {
//    bool eof = bytes < sizeof(buffer);
//    S_parser_feed(parser, buffer, bytes, eof);
//    if (eof) {
//      break;
//    }
//  }
//
//  document = cmark_parser_finish(parser);
//  cmark_parser_free(parser);
//  return document;
//}

/** Parse a CommonMark document in 'buffer' of length 'len'.
 * Returns a pointer to a tree of nodes.  The memory allocated for
 * the node tree should be released using 'cmark_node_free'
 * when it is no longer needed.
 */
public func cmark_parse_document(_ str: String, _ options: CmarkOptions) -> CmarkNode {
    var data = str.data(using: .utf8)!
    data.append(0)
    return cmark_parse_document(data, options)
}
public func cmark_parse_document(_ data: Data, _ options: CmarkOptions) -> CmarkNode {
    return autoreleasepool {
        let parser = CmarkParser(options: options)
        
        parser.feed(data)
        
        let document = parser.finish()
        parser.free()
        return document
    }
}

extension CmarkParser {
    
    /** Feeds a string of length 'len' to 'parser'.
     */
    public func feed(_ data: Data) {
        data.withUnsafeBytes {bytes in
            feed(bytes, data.count - 1, false)
        }
    }
    
    private func feed(_ _buffer: UnsafePointer<UInt8>,
                      _ len: Int, _ eof: Bool) {
        var buffer = _buffer
        let end = buffer + len
        
        if lastBufferEndedWithCr && buffer.pointee == "\n" {
            // skip NL if last buffer ended with CR ; see #117
            buffer += 1
        }
        lastBufferEndedWithCr = false
        while buffer < end {
            var process = false
            var eol: UnsafePointer<UInt8> = buffer
            while eol < end {
                if eol.pointee.isLineEnd {
                    process = true
                    break
                }
                if eol < end && eol.pointee == "\0" {
                    break
                }
                eol += 1
            }
            if eol >= end && eof {
                process = true
            }
            
            let chunkLen = eol - buffer
            if process {
                linebuf.put(buffer, chunkLen, options.contains(.validateUTF8))
                processLine(linebuf)
                linebuf.clear()
            } else {
                if eol < end && eol.pointee == "\0" {
                    // omit NULL byte
                    linebuf.put(buffer, chunkLen, options.contains(.validateUTF8))
                    // add replacement character
                    linebuf.put("\u{FFFD}")
                } else {
                    linebuf.put(buffer, chunkLen, options.contains(.validateUTF8))
                }
            }
            
            buffer += chunkLen
            if buffer < end {
                if buffer.pointee == "\0" {
                    // skip over NULL
                    buffer += 1
                } else {
                    // skip over line ending characters
                    if buffer.pointee == "\r" {
                        buffer += 1
                        if buffer == end {
                            lastBufferEndedWithCr = true
                        }
                    }
                    if buffer < end && buffer.pointee == "\n" {
                        buffer += 1
                    }
                }
            }
        }
    }
}

extension StringChunk {
    fileprivate func chopTrailingHashtags() {
        
        rtrim()
        var n = index(before: endIndex)
        let origN = n
        
        // if string ends in space followed by #s, remove these:
        while n >= startIndex && self[n] == "#" {
            if n == startIndex {
                return
            }
            n = index(before: n)
        }
        
        // Check for a space before the final #s:
        if n < origN && self[n].isSpaceOrTab {
            truncate(n)
            rtrim()
        }
    }
}

extension CmarkParser {
    // Find first nonspace character from current offset, setting
    // parser->first_nonspace, parser->first_nonspace_column,
    // parser->indent, and parser->blank. Does not advance parser->offset.
    func findFirstNonspace(input: StringChunk) {
        var charsToTab = TAB_STOP - (column % TAB_STOP)
        
        firstNonspaceIndex = parseIndex
        firstNonspaceColumn = column
        while case let c = input[firstNonspaceIndex], c != "\0" {
            if c == " " {
                firstNonspaceIndex = input.index(after: firstNonspaceIndex)
                firstNonspaceColumn += 1
                charsToTab -= 1
                if charsToTab == 0 {
                    charsToTab = TAB_STOP
                }
            } else if c == "\t" {
                firstNonspaceIndex = input.index(after: firstNonspaceIndex)
                firstNonspaceColumn += charsToTab
                charsToTab = TAB_STOP
            } else {
                break
            }
        }
        
        indent = firstNonspaceColumn - column
        blank = input[firstNonspaceIndex].isLineEnd
    }
    
    // Advance parser->offset and parser->column.  parser->offset is the
    // byte position in input; parser->column is a virtual column number
    // that takes into account tabs. (Multibyte characters are not taken
    // into account, because the Markdown line prefixes we are interested in
    // analyzing are entirely ASCII.)  The count parameter indicates
    // how far to advance the offset.  If columns is true, then count
    // indicates a number of columns; otherwise, a number of bytes.
    // If advancing a certain number of columns partially consumes
    // a tab character, parser->partially_consumed_tab is set to true.
    func advanceOffset(input: StringChunk, to: String.Index,
                       offset: Int = 0, columns: Bool) {
        let toIndex = input.index(to, offsetBy: offset)
        var count = input.distance(from: parseIndex, to: toIndex)
        while count > 0, case let c = input[parseIndex], c != "\0" {
            if c == "\t" {
                let charsToTab = TAB_STOP - (column % TAB_STOP)
                if columns {
                    partiallyConsumedTab = charsToTab > count
                    let charsToAdvance = min(count, charsToTab)
                    column += charsToAdvance
                    parseIndex = input.index(parseIndex, offsetBy: partiallyConsumedTab ? 0 : 1)
                    count -= charsToAdvance
                } else {
                    partiallyConsumedTab = false
                    column += charsToTab
                    parseIndex = input.index(after: parseIndex)
                    count -= 1
                }
            } else {
                partiallyConsumedTab = false
                parseIndex = input.index(after: parseIndex)
                column += 1 // assume ascii; block starts are ascii
                count -= 1
            }
        }
    }
}

extension CmarkNode {
    var lastChildIsOpen: Bool {
        return lastChild != nil &&
            lastChild!.flags.contains(.open)
    }
}

extension StringChunk {
    fileprivate func scanHtmlBlockStartN7(_ index: String.Index, _ contType: CmarkNodeType) -> Int {
        var matchlen = scanHtmlBlockStart(index)
        if matchlen != 0 {return matchlen}
        if contType != .paragraph {
            matchlen = scanHtmlBlockStart7(index)
        }
        return matchlen
    }
}

extension CmarkParser {
    func parseBlockQuotePrefix(input: StringChunk) -> Bool {
        var res = false
        
        let matched = indent <= 3 && input[firstNonspaceIndex] == ">"
        if matched {
            
            advanceOffset(input: input, to: parseIndex, offset: indent + 1, columns: true)
            
            if input[parseIndex].isSpaceOrTab {
                advanceOffset(input: input, to: parseIndex, offset: 1, columns: true)
            }
            
            res = true
        }
        return res
    }
    
    func parseNodeItemPrefix(input: StringChunk, container: CmarkNode) -> Bool {
        var res = false
        
        if indent >=
            (container.asList?.markerOffset ?? 0) + (container.asList?.padding ?? 0) {
            advanceOffset(input: input, to: parseIndex, offset: container.asList!.markerOffset + container.asList!.padding, columns: true)
            res = true
        } else if blank && container.firstChild != nil {
            // if container->first_child is NULL, then the opening line
            // of the list item was blank after the list marker; in this
            // case, we are done with the list item.
            advanceOffset(input: input, to: firstNonspaceIndex, offset: 0, columns: false)
            res = true
        }
        return res
    }
    
    func parseCodeBlockPrefix(input: StringChunk, container: CmarkNode, shouldContinue: inout Bool) -> Bool {
        var res = false
        
        if !(container.asCode?.fenced ?? false) {
            if indent >= CODE_INDENT {
                advanceOffset(input: input, to: parseIndex, offset: CODE_INDENT, columns: true)
                res = true
            } else if blank {
                
                advanceOffset(input: input, to: firstNonspaceIndex, columns: false)
                res = true
            }
        } else { // fenced
            var matched = 0
            
            if indent <= 3 && input[firstNonspaceIndex] ==
                container.asCode!.fenceChar {
                matched = input.scanCloseCodeFence(firstNonspaceIndex)
            }
            
            if matched >= container.asCode!.fenceLength {
                // closing fence - and since we're at
                // the end of a line, we can stop processing it:
                shouldContinue = false
                advanceOffset(input: input, to: parseIndex, offset: matched, columns: false)
                current = finalize(container)
            } else {
                // skip opt. spaces of fence parser->offset
                var i = container.asCode!.fenceOffset
                
                while i > 0 && input[parseIndex].isSpaceOrTab {
                    advanceOffset(input: input, to: parseIndex, offset: 1, columns: true)
                    i -= 1
                }
                res = true
            }
        }
        
        return res
    }
    
    func parseHtmlBlockPrefix(container: CmarkNode) -> Bool {
        var res = false
        let htmlBlockType = container.asHtmlBlockType!
        
        assert(htmlBlockType >= 1 && htmlBlockType <= 7)
        switch htmlBlockType {
        case 1, 2, 3, 4, 5:
            // these types of blocks can accept blanks
            res = true
        case 6, 7:
            res = !blank
        default:
            break
        }
        
        return res
    }
    
    /**
     * For each containing node, try to parse the associated line start.
     *
     * Will not close unmatched blocks, as we may have a lazy continuation
     * line -> http://spec.commonmark.org/0.24/#lazy-continuation-line
     *
     * Returns: The last matching node, or NULL
     */
    func checkOpenBlocks(input: StringChunk, allMatched: inout Bool) -> CmarkNode? {
        var shouldContinue = true
        allMatched = false
        var container: CmarkNode? = root
        
        doneOnBreak: do {
            while container?.lastChildIsOpen == true {
                container = container!.lastChild
                let contType = container!.type
                
                findFirstNonspace(input: input)
                
                switch contType {
                case .blockQuote:
                    if !parseBlockQuotePrefix(input: input) {
                        break doneOnBreak
                    }
                case .item:
                    if !parseNodeItemPrefix(input: input, container: container!) {
                        break doneOnBreak
                    }
                case .codeBlock:
                    if !parseCodeBlockPrefix(input: input, container: container!, shouldContinue: &shouldContinue) {
                        break doneOnBreak
                    }
                case .heading:
                    // a heading can never contain more than one line
                    break doneOnBreak
                case .htmlBlock:
                    if !parseHtmlBlockPrefix(container: container!) {
                        break doneOnBreak
                    }
                case .paragraph:
                    if blank {
                        break doneOnBreak
                    }
                default:
                    break
                }
            }
            
            allMatched = true
        } //### doneOnBreak
        if !allMatched {
            container = container?.parent // back up to last matching node
        }
        
        if !shouldContinue {
            container = nil
        }
        
        return container
    }
    
    func openNewBlocks(container: inout CmarkNode,
                       input: StringChunk, allMatched: Bool) {
        var data: CmarkList? = nil
        var maybeLazy = current?.type == .paragraph
        var contType = container.type
        
        while contType != .codeBlock && contType != .htmlBlock {
            var shouldBreak = false
            autoreleasepool{
                findFirstNonspace(input: input)
                let indented = indent >= CODE_INDENT
                
                if !indented && input[firstNonspaceIndex] == ">" {
                    
                    let blockquoteStartColumn = firstNonspaceColumn
                    
                    advanceOffset(input: input, to: firstNonspaceIndex, offset: 1, columns: false)
                    if input[parseIndex].isSpaceOrTab {
                        
                        advanceOffset(input: input, to: parseIndex, offset: 1, columns: true)
                    }
                    container = addChild(parent: container, blockType: .blockQuote,
                                         startColumn: blockquoteStartColumn + 1)
                    
                } else if !indented,
                    case let matched = input.scanAtxHeadingStart(firstNonspaceIndex), matched != 0 {
                    var level = 0
                    let headingStartColumn = firstNonspaceColumn
                    
                    advanceOffset(input: input,
                                  to: firstNonspaceIndex, offset: matched,
                                  columns: false)
                    container = addChild(parent: container, blockType: .heading,
                                         startColumn: headingStartColumn + 1)
                    
                    var hashIndex = input.strchr("#", firstNonspaceIndex)!
                    
                    while input[hashIndex] == "#" {
                        level += 1
                        hashIndex = input.index(after: hashIndex)
                    }
                    
                    container.asType = .heading(CmarkHeading(level: level, setext: false))
                    container.internalOffset = matched
                    
                } else if !indented,
                    case let matched = input.scanOpenCodeFence(firstNonspaceIndex), matched != 0 {
                    container = addChild(parent: container, blockType: .codeBlock,
                                         startColumn: firstNonspaceColumn + 1)
                    var code = container.asCode ?? CmarkCode()
                    code.fenced = true
                    code.fenceChar = input[firstNonspaceIndex]
                    code.fenceLength = (matched > 255) ? 255 : matched
                    code.fenceOffset = input.distance(from: parseIndex, to: firstNonspaceIndex)
                    code.info = StringChunk(literal: "")
                    container.asType = .code(code)
                    advanceOffset(input: input,
                                  to: firstNonspaceIndex, offset: matched,
                                  columns: false)
                    
                } else if !indented,
                    case let matched = input.scanHtmlBlockStartN7(firstNonspaceIndex, contType),
                    matched != 0 {
                    container = addChild(parent: container, blockType: .htmlBlock,
                                         startColumn: firstNonspaceColumn + 1)
                    container.asType = .htmlBlockType(matched)
                    // note, we don't adjust parser->offset because the tag is part of the
                    // text
                } else if !indented && contType == .paragraph,
                    case let lev = input.scanSetextHeadingLine(firstNonspaceIndex), lev != 0 {
                    container.type = .heading
                    container.asType = .heading(CmarkHeading(level: lev, setext: true))
                    advanceOffset(input: input, to: input.endIndex, offset: -1, columns: false)
                } else if !indented,
                    !(contType == .paragraph && !allMatched),
                    case let matched = input.scanThematicBreak(firstNonspaceIndex), matched != 0 {
                    // it's only now that we know the line is not part of a setext heading:
                    container = addChild(parent: container, blockType: .thematicBreak,
                                         startColumn: firstNonspaceColumn + 1)
                    advanceOffset(input: input, to: input.endIndex, offset:  -1, columns: false)
                } else if (!indented || contType == .list),
                    case let matched = input.parseListMarker(
                        index: firstNonspaceIndex,
                        interruptsParagraph: container.type == .paragraph, dataptr: &data), matched != 0,
                    var data = data {
                    
                    // Note that we can have new list items starting with >= 4
                    // spaces indent, as long as the list container is still open.
                    var i = 0
                    
                    // compute padding:
                    advanceOffset(input: input,
                                  to: firstNonspaceIndex, offset: matched,
                                  columns: false)
                    
                    let savePartiallyConsumedTab = partiallyConsumedTab
                    let saveIndex = parseIndex
                    let saveColumn = column
                    
                    while column - saveColumn <= 5 &&
                        input[parseIndex].isSpaceOrTab {
                            advanceOffset(input: input, to: parseIndex, offset: 1, columns: true)
                    }
                    
                    i = column - saveColumn
                    if i >= 5 || i < 1 ||
                        // only spaces after list marker:
                        input[parseIndex].isLineEnd {
                        data.padding = matched + 1
                        parseIndex = saveIndex
                        column = saveColumn
                        partiallyConsumedTab = savePartiallyConsumedTab
                        if i > 0 {
                            advanceOffset(input: input, to: parseIndex, offset: 1, columns: true)
                        }
                    } else {
                        data.padding = matched + i
                    }
                    
                    // check container; if it's a list, see if this list item
                    // can continue the list; otherwise, create a list container.
                    
                    data.markerOffset = indent
                    
                    if contType != .list ||
                        !(container.asList?.doesMatch(data) ?? false) {
                        container = addChild(parent: container, blockType: .list,
                                             startColumn: firstNonspaceColumn + 1)
                        
                        container.asType = .list(data)
                    }
                    
                    // add the list item
                    container = addChild(parent: container, blockType: .item,
                                         startColumn: firstNonspaceColumn + 1)
                    /* TODO: static */
                    container.asType = .list(data)
                } else if indented && !maybeLazy && !blank {
                    advanceOffset(input: input, to: parseIndex, offset: CODE_INDENT, columns: true)
                    container = addChild(parent: container, blockType: .codeBlock,
                                         startColumn: column + 1)
                    var code = container.asCode ?? CmarkCode()
                    code.fenced = false
                    code.fenceChar = "\0"
                    code.fenceLength = 0
                    code.fenceOffset = 0
                    code.info = StringChunk(literal: "")
                    container.asType = .code(code)
                    
                } else {
                    shouldBreak = true
                }
            }
            
            if shouldBreak || container.type.acceptsLines {
                // if it's a line container, it can't contain other containers
                break
            }
            
            contType = container.type
            maybeLazy = false
        }
    }
    
    func add(to _container: CmarkNode, lastMatchedContainer: CmarkNode?, text input: StringChunk) {
        var container = _container
        // what remains at parser->offset is a text line.  add the text to the
        // appropriate container.
        
        findFirstNonspace(input: input)
        
        if blank, let lastChild = container.lastChild {
            lastChild.setLastLineBlank(true)
        }
        
        // block quote lines are never blank as they start with >
        // and we don't count blanks in fenced code for purposes of tight/loose
        // lists or breaking out of lists.  we also don't set last_line_blank
        // on an empty list item.
        let ctype = container.type
        let lastLineBlank =
            (blank && ctype != .blockQuote &&
                ctype != .heading && ctype != .thematicBreak &&
                !(ctype == .codeBlock && container.asCode?.fenced ?? false) &&
                !(ctype == .item && container.firstChild == nil &&
                    container.startLine == lineNumber))
        
        container.setLastLineBlank(lastLineBlank)
        
        var tmp = container
        while let parent = tmp.parent {
            parent.setLastLineBlank(false)
            tmp = parent
        }
        
        // If the last line processed belonged to a paragraph node,
        // and we didn't match all of the line prefixes for the open containers,
        // and we didn't start any new containers,
        // and the line isn't blank,
        // then treat this as a "lazy continuation line" and add it to
        // the open paragraph.
        if current !== lastMatchedContainer &&
            container === lastMatchedContainer && !blank &&
            current?.type == .paragraph {
            add(to: current!, line: input)
        } else { // not a lazy continuation
            // Finalize any blocks that were not matched and set cur to container:
            while current !== lastMatchedContainer {
                current = finalize(current!)
                assert(current != nil)
            }
            
            if container.type == .codeBlock {
                add(to: container, line: input)
            } else if container.type == .htmlBlock {
                add(to: container, line: input)
                
                let matchesEndCondition: Int
                switch container.asHtmlBlockType ?? 0 {
                case 1:
                    // </script>, </style>, </pre>
                    matchesEndCondition =
                        input.scanHtmlBlockEnd1(firstNonspaceIndex)
                case 2:
                    // -->
                    matchesEndCondition =
                        input.scanHtmlBlockEnd2(firstNonspaceIndex)
                case 3:
                    // ?>
                    matchesEndCondition =
                        input.scanHtmlBlockEnd3(firstNonspaceIndex)
                case 4:
                    // >
                    matchesEndCondition =
                        input.scanHtmlBlockEnd4(firstNonspaceIndex)
                case 5:
                    // ]]>
                    matchesEndCondition =
                        input.scanHtmlBlockEnd5(firstNonspaceIndex)
                default:
                    matchesEndCondition = 0
                }
                
                if matchesEndCondition != 0 {
                    container = finalize(container)!
                    assert(current != nil)
                }
            } else if blank {
                // ??? do nothing
            } else if container.type.acceptsLines {
                if container.type == .heading &&
                    container.asHeading?.setext == false {
                    input.chopTrailingHashtags()
                }
                advanceOffset(input: input, to: firstNonspaceIndex,
                              columns: false)
                add(to: container, line: input)
            } else {
                // create paragraph container for line
                container = addChild(parent: container, blockType: .paragraph,
                                     startColumn: firstNonspaceColumn + 1)
                advanceOffset(input: input, to: firstNonspaceIndex,
                              columns: false)
                add(to: container, line: input)
            }
            
            current = container
        }
    }
    
    /* See http://spec.commonmark.org/0.24/#phase-1-block-structure */
    func processLine(_ strbuf: StringBufferType) {
        processLine(strbuf.string, strbuf.startIndex, strbuf.endIndex)
    }
    func processLine(_ string: String, _ startIndex: String.Index, _ endIndex: String.Index) {
        var allMatched = true
        autoreleasepool{
            curline.put(string, startIndex, endIndex)
            
            // ensure line ends with a newline:
            if curline.isEmpty || !curline.last!.isLineEnd {
                curline.putc("\n")
            }
            
            column = 0
            blank = false
            partiallyConsumedTab = false
            
            let input = StringChunk(content: curline)
            parseIndex = input.startIndex
            
            lineNumber += 1
            
            if let lastMatchedContainer = checkOpenBlocks(input: input, allMatched: &allMatched) {
                
                var container = lastMatchedContainer
                openNewBlocks(container: &container, input: input, allMatched: allMatched)
                
                add(to: container, lastMatchedContainer: lastMatchedContainer, text: input)
                
            }
            
            lastLineLength = input.len
            if lastLineLength != 0 &&
                input[lastLineLength - 1] == "\n" {
                lastLineLength -= 1
            }
            if lastLineLength != 0 &&
                input[lastLineLength - 1] == "\r" {
                lastLineLength -= 1
            }
            
            curline.clear()
        }
    }
    
    
    /** Finish parsing and return a pointer to a tree of nodes.
     */
    public func finish() -> CmarkNode {
        if linebuf.size > 0 {
            processLine(linebuf)
            linebuf.clear()
        }
        
        finalizeDocument()
        
        root.consolidateTextNodes()
        
        curline.free()
        
        #if CMARK_DEBUG_NODES
            if root.check(stderr) != 0 {
                fatalError()
            }
        #endif
        return root
    }
}
