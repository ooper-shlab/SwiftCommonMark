//
//  Inlines.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/17.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on inlines.c and inlines.h
 https://github.com/commonmark/cmark/blob/master/src/inlines.c
 https://github.com/commonmark/cmark/blob/master/src/inlines.h
 */

import Foundation

private let EMDASH = "—" //U+2014 EM DASH
private let ENDASH = "–" //U+2013 EN DASH
private let ELLIPSES = "…" //U+2026 HORIZONTAL ELLIPSIS
private let LEFTDOUBLEQUOTE = "“"   //U+201C LEFT DOUBLE QUOTATIOON MARK
private let RIGHTDOUBLEQUOTE = "”"   //U+201D RIGHT DOUBLE QUOTATIOON MARK
private let LEFTSINGLEQUOTE = "‘"   //U+2018 LEFT SINGLE QUOTATIOON MARK
private let RIGHTSINGLEQUOTE = "’"   //U+2019 RIGHT SINGLE QUOTATIOON MARK

// Macros for creating various kinds of simple.
extension Subject {
    fileprivate func makeStr(_ sc: Int, _ ec: Int, _ s: CmarkChunk) -> CmarkNode {
        return makeLiteral(.text, sc, ec, s)
    }
    fileprivate func makeCode(_ sc: Int, _ ec: Int, _ s: CmarkChunk) -> CmarkNode {
        return makeLiteral(.code, sc, ec, s)
    }
    fileprivate func makeRawHtml(_ sc: Int, _ ec: Int, _ s: CmarkChunk) -> CmarkNode {
        return makeLiteral(.htmlInline, sc, ec, s)
    }
}
private func makeLinebreak() -> CmarkNode {return CmarkNode(simple: .linebreak)}
private func makeSoftbreak() -> CmarkNode {return CmarkNode(simple: .softbreak)}
private func makeEmph() -> CmarkNode {return CmarkNode(simple: .emph)}
private func makeStrong() -> CmarkNode {return CmarkNode(simple: .strong)}

private let MAXBACKTICKS = 1000

class Delimiter {
    var previous: Delimiter?
    weak var next: Delimiter?
    var inlText: CmarkNode?
    var length: Int = 0
    var delimChar: UInt8 = 0
    var canOpen: Bool = false
    var canClose: Bool = false
}

class Bracket {
    var previous: Bracket?
    var previousDelimiter: Delimiter?
    var inlText: CmarkNode?
    var position: Int = 0
    var image: Bool = false
    var active: Bool = false
    var bracketAfter: Bool = false
}

class Subject {
    var input: CmarkChunk
    var line: Int = 0
    var pos: Int = 0
    var blockOffset: Int = 0
    var columnOffset: Int = 0
    var refmap: CmarkReferenceMap?
    var lastDelim: Delimiter?
    var lastBracket: Bracket?
    var backticks: [Int] = Array(repeating: 0, count: MAXBACKTICKS+1)
    var scannedForBackticks: Bool = false
    
    init(input: CmarkChunk, refmap: CmarkReferenceMap?) {
        self.input = input
        self.refmap = refmap
    }
}

extension UInt8 {
    var isLineEnd: Bool {
        return self == "\n" || self == "\r"
    }
}

extension Subject {
    // Create an inline with a literal string value.
    private func makeLiteral(_ t: CmarkNodeType,
                             _ startColumn: Int, _ endColumn: Int,
                             _ s: CmarkChunk) -> CmarkNode {
        let e = CmarkNode(t)
        e.asType = .literal(s)
        e.startLine = line
        e.endLine = line
        // columns are 1 based.
        e.startColumn = startColumn + 1 + columnOffset + blockOffset
        e.endColumn = endColumn + 1 + columnOffset + blockOffset
        return e
    }
}

extension CmarkNode {
    // Create an inline with no value.
    convenience init(simple t: CmarkNodeType) {
        self.init(tag: t, content: CmarkStrbuf(initialSize: 0), flags: [])
    }
}

extension Subject {
    // Like make_str, but parses entities.
    fileprivate func makeStrWithEntities(
        _ startColumn: Int, _ endColumn: Int,
        _ content: CmarkChunk) -> CmarkNode {
        let unescaped = CmarkStrbuf()
        
        if unescaped.unescapeHtml(content.data,content.len) {
            return makeStr(startColumn, endColumn, unescaped.bufDetach())
        } else {
            return makeStr(startColumn, endColumn, content)
        }
    }
}

extension CmarkChunk {
    // Duplicate a chunk by creating a copy of the buffer not by reusing the
    // buffer like cmark_chunk_dup does.
    fileprivate func clone() -> CmarkChunk {
        let len = self.len
        
        let c = CmarkChunk()
        c.len = len
        c.data = .allocate(capacity: len + 1)
        c.data.initialize(to: 0, count: len + 1)
        c.alloc = len + 1
        if len != 0 {
            memcpy(c.data, self.data, len)
        }
        c.data[len] = "\0"
        
        return c
    }
}

private func cmark_clean_autolink(_ url: CmarkChunk,
                                  _ isEmail: Bool) -> CmarkChunk {
    let buf = CmarkStrbuf()
    
    url.trim()
    
    if url.len == 0 {
        let result = CMARK_CHUNK_EMPTY
        return result
    }
    
    if isEmail {
        buf.puts("mailto:")
    }
    
    buf.unescapeHtmlF(url.data, url.len)
    return buf.bufDetach()
}

extension Subject {
    fileprivate func makeAutolink(
        _ startColumn: Int, _ endColumn: Int,
        _ url: CmarkChunk, _ isEmail: Bool) -> CmarkNode {
        let link = CmarkNode(simple: .link)
        let linkUrl = cmark_clean_autolink(url, isEmail)
        let title = CmarkChunk(literal: "")
        let clink = CmarkLink(url: linkUrl, title: title)
        link.asType = .link(clink)
        link.startLine = line
        link.endLine = line
        link.startColumn = startColumn + 1
        link.endColumn = endColumn + 1
        link.append(child: makeStrWithEntities(startColumn + 1, endColumn - 1, url))
        return link
    }
    
    convenience init(lineNumber: Int, blockOffset: Int, chunk: CmarkChunk, refmap: CmarkReferenceMap?) {
        self.init(input: chunk, refmap: refmap)
        self.line = lineNumber
        self.pos = 0
        self.blockOffset = blockOffset
        self.columnOffset = 0
        self.lastDelim = nil
        self.lastBracket = nil
        for i in 0...MAXBACKTICKS {
            self.backticks[i] = 0
        }
        self.scannedForBackticks = false
    }
}

private func isbacktick(_ c: UInt8) -> Bool {return c == "`"}

extension Subject {
    func peekChar() -> UInt8 {
        // NULL bytes should have been stripped out by now.  If they're
        // present, it's a programming error:
        assert(!(pos < input.len && input.data[pos] == 0))
        return pos < input.len ? input.data[pos] : 0
    }
    
    fileprivate func peek(at pos: Int) -> UInt8 {
        return input.data[pos]
    }
    
    // Return true if there are more characters in the subject.
    var isEof: Bool {
        return pos >= input.len
    }
    
    // Advance the subject.  Doesn't check for eof.
    func advance() {pos += 1}
    
    @discardableResult
    func skipSpaces() -> Bool {
        var skipped = false
        while peekChar() == " " || peekChar() == "\t" {
            advance()
            skipped = true
        }
        return skipped
    }
    
    @discardableResult
    func skipLineEnd() -> Bool {
        var seenLineEndChar = false
        if peekChar() == "\r" {
            advance()
            seenLineEndChar = true
        }
        if peekChar() == "\n" {
            advance()
            seenLineEndChar = true
        }
        return seenLineEndChar || isEof
    }
    
    // Take characters while a predicate holds, and return a string.
    fileprivate func takeWhile(_ f: (UInt8)->Bool) -> CmarkChunk {
        let startpos = pos
        var len = 0
        
        while case let c = peekChar(), f(c) {
            advance()
            len += 1
        }
        
        return input.dup(pos: startpos, len: len)
    }
    
    // Return the number of newlines in a given span of text in a subject.  If
    // the number is greater than zero, also return the number of characters
    // between the last newline and the end of the span in `since_newline`.
    fileprivate func countNewlines(from _from: Int, len _len: Int, sinceNewline: inout Int) -> Int {
        var from = _from
        var len = _len
        var nls = 0
        var sinceNl = 0
        
        while len != 0 {
            len -= 1
            if input.data[from] == "\n" {
                nls += 1
                sinceNl = 0
            } else {
                sinceNl += 1
            }
            from += 1
        }
        
        if nls == 0 {
            return 0
        }
        
        sinceNewline = sinceNl
        return nls
    }
    
    // Adjust `node`'s `end_line`, `end_column`, and `subj`'s `line` and
    // `column_offset` according to the number of newlines in a just-matched span
    // of text in `subj`.
    fileprivate func adjustSubjNodeNewlines(_ node: CmarkNode, _ matchlen: Int, _ extra: Int, _ options: CmarkOptions) {
        if !options.contains(.sourcepos) {
            return
        }
        
        var sinceNewline: Int = 0
        let newlines = countNewlines(from: pos - matchlen - extra, len: matchlen, sinceNewline: &sinceNewline)
        if newlines != 0 {
            line += newlines
            node.endLine += newlines
            node.endColumn = sinceNewline
            columnOffset = -pos + sinceNewline + extra
        }
    }
    
    // Try to process a backtick code span that began with a
    // span of ticks of length openticklength length (already
    // parsed).  Return 0 if you don't find matching closing
    // backticks, otherwise return the position in the subject
    // after the closing backticks.
    fileprivate func scanToClosingBackticks(
        _ openticklength: Int) -> Int {
        
        if openticklength > MAXBACKTICKS {
            // we limit backtick string length because of the array subj->backticks:
            return 0
        }
        if scannedForBackticks &&
            backticks[openticklength] <= pos {
            // return if we already know there's no closer
            return 0
        }
        while true {
            // read non backticks
            while case let c = peekChar(), c != 0, c != "`" {
                advance()
            }
            if isEof {
                break
            }
            var numticks = 0
            while peekChar() == "`" {
                advance()
                numticks += 1
            }
            // store position of ender
            if numticks <= MAXBACKTICKS {
                backticks[numticks] = pos - numticks
            }
            if numticks == openticklength {
                return pos
            }
        }
        // got through whole input without finding closer
        scannedForBackticks = true
        return 0
    }
    
    // Parse backtick code section or raw backticks, return an inline.
    // Assumes that the subject has a backtick at the current position.
    fileprivate func handleBackticks(_ options: CmarkOptions) -> CmarkNode {
        let openticks = takeWhile(isbacktick)
        let startpos = pos
        let endpos = scanToClosingBackticks(openticks.len)
        
        if endpos == 0 {      // not found
            pos = startpos // rewind
            return makeStr(pos, pos, openticks)
        } else {
            let buf = CmarkStrbuf()
            
            buf.set(input.data + startpos,
                    endpos - startpos - openticks.len)
            buf.trim()
            buf.normalizeWhitespace()
            
            let node = makeCode(startpos, endpos - openticks.len - 1, buf.bufDetach())
            adjustSubjNodeNewlines(node, endpos - startpos, openticks.len, options)
            return node
        }
    }
    
    // Scan ***, **, or * and return number scanned, or 0.
    // Advances position.
    fileprivate func scanDelims(_ c: UInt8, canOpen: inout Bool,
                                canClose: inout Bool) -> Int {
        var numdelims = 0
        var afterChar: Int32 = 0
        var beforeChar: Int32 = 0
        
        if pos == 0 {
            beforeChar = 10
        } else {
            var beforeCharPos = pos - 1
            // walk back to the beginning of the UTF_8 sequence:
            while peek(at: beforeCharPos) >> 6 == 2 && beforeCharPos > 0 {
                beforeCharPos -= 1
            }
            let len = cmark_utf8proc_iterate(input.data + beforeCharPos,
                                             pos - beforeCharPos, &beforeChar)
            if len == -1 {
                beforeChar = 10
            }
        }
        
        if c == "'" || c == "\"" {
            numdelims += 1
            advance() // limit to 1 delim for quotes
        } else {
            while peekChar() == c {
                numdelims += 1
                advance()
            }
        }
        
        let len = cmark_utf8proc_iterate(input.data + pos,
                                         input.len - pos, &afterChar)
        if len == -1 {
            afterChar = 10
        }
        let leftFlanking = numdelims > 0 && !cmark_utf8proc_is_space(afterChar) &&
            (!cmark_utf8proc_is_punctuation(afterChar) ||
                cmark_utf8proc_is_space(beforeChar) ||
                cmark_utf8proc_is_punctuation(beforeChar))
        let rightFlanking = numdelims > 0 && !cmark_utf8proc_is_space(beforeChar) &&
            (!cmark_utf8proc_is_punctuation(beforeChar) ||
                cmark_utf8proc_is_space(afterChar) ||
                cmark_utf8proc_is_punctuation(afterChar));
        if c == "_" {
            canOpen = leftFlanking &&
                (!rightFlanking || cmark_utf8proc_is_punctuation(beforeChar))
            canClose = rightFlanking &&
                (!leftFlanking || cmark_utf8proc_is_punctuation(afterChar))
        } else if c == "'" || c == "\"" {
            canOpen = leftFlanking && !rightFlanking &&
                beforeChar != Int32(("]" as UnicodeScalar).value) && beforeChar != Int32((")" as UnicodeScalar).value)
            canClose = rightFlanking
        } else {
            canOpen = leftFlanking
            canClose = rightFlanking
        }
        return numdelims
    }
    
    /*
     static void print_delimiters(subject *subj)
     {
     delimiter *delim;
     delim = subj->last_delim;
     while (delim != NULL) {
     printf("Item at stack pos %p: %d %d %d next(%p) prev(%p)\n",
     (void*)delim, delim->delim_char,
     delim->can_open, delim->can_close,
     (void*)delim->next, (void*)delim->previous);
     delim = delim->previous;
     }
     }
     */
    
    func remove(_ delim: Delimiter?) {
        guard let theDelim = delim else {
            return
        }
        if theDelim.next == nil {
            // end of list:
            assert(delim === self.lastDelim)
            lastDelim = theDelim.previous
        } else {
            theDelim.next?.previous = theDelim.previous
        }
        if let previous = theDelim.previous {
            previous.next = theDelim.next
        }
    }
    
    fileprivate func popBracket() {
        guard let b = lastBracket else {
            return
        }
        lastBracket = b.previous
    }
    
    fileprivate func pushDelimiter(_ c: UInt8, canOpen: Bool,
                                   canClose: Bool, inlText: CmarkNode) {
        let delim = Delimiter()
        delim.delimChar = c
        delim.canOpen = canOpen
        delim.canClose = canClose
        delim.inlText = inlText
        delim.length = inlText.asLiteral?.len ?? 0
        delim.previous = lastDelim
        delim.next = nil
        if let prev = delim.previous {
            prev.next = delim
        }
        lastDelim = delim
    }
    
    fileprivate func pushBracket(image: Bool, inlText: CmarkNode) {
        let b = Bracket()
        if let bracket = lastBracket {
            bracket.bracketAfter = true
        }
        b.image = image
        b.active = true
        b.inlText = inlText
        b.previous = lastBracket
        b.previousDelimiter = lastDelim
        b.position = pos
        b.bracketAfter = false
        lastBracket = b
    }
    
    // Assumes the subject has a c at the current position.
    fileprivate func handleDelim(_ c: UInt8, _ smart: Bool) -> CmarkNode {
        var canOpen: Bool = false, canClose: Bool = false
        let contents: CmarkChunk
        
        let numdelims = scanDelims(c, canOpen: &canOpen, canClose: &canClose)
        
        if c == "'" && smart {
            contents = CmarkChunk(literal: RIGHTSINGLEQUOTE)
        } else if c == "\"" && smart {
            contents =
                CmarkChunk(literal: canClose ? RIGHTDOUBLEQUOTE : LEFTDOUBLEQUOTE)
        } else {
            contents = input.dup(pos: pos - numdelims, len: numdelims)
        }
        
        let inlText = makeStr(pos - numdelims, pos - 1, contents)
        
        if (canOpen || canClose) && (!(c == "'" || c == "\"") || smart) {
            pushDelimiter(c, canOpen: canOpen, canClose: canClose, inlText: inlText)
        }
        
        return inlText
    }
    
    // Assumes we have a hyphen at the current position.
    fileprivate func handleHyphen(_ smart: Bool) -> CmarkNode {
        let startpos = pos
        
        advance()
        
        if !smart || peekChar() != "-" {
            return makeStr(pos - 1, pos - 1, CmarkChunk(literal: "-"))
        }
        
        while smart && peekChar() == "-" {
            advance()
        }
        
        let numhyphens = pos - startpos
        var enCount = 0
        var emCount = 0
        let buf = CmarkStrbuf()
        
        if numhyphens % 3 == 0 {
            emCount = numhyphens / 3
        } else if numhyphens % 2 == 0 { // if divisible by 2, use all en dashes
            enCount = numhyphens / 2
        } else if numhyphens % 3 == 2 { // use one en dash at end
            enCount = 1
            emCount = (numhyphens - 2) / 3
        } else { // use two en dashes at the end
            enCount = 2
            emCount = (numhyphens - 4) / 3
        }
        
        for _ in 0..<emCount {
            buf.puts(EMDASH)
        }
        
        for _ in 0..<enCount {
            buf.puts(ENDASH)
        }
        
        return makeStr(startpos, pos - 1, buf.bufDetach())
    }
    
    // Assumes we have a period at the current position.
    fileprivate func handlePeriod(_ smart: Bool) -> CmarkNode {
        advance()
        if smart && peekChar() == "." {
            advance()
            if peekChar() == "." {
                advance()
                return makeStr(pos - 3, pos - 1, CmarkChunk(literal: ELLIPSES))
            } else {
                return makeStr(pos - 2, pos - 1, CmarkChunk(literal: ".."))
            }
        } else {
            return makeStr(pos - 1, pos - 1, CmarkChunk(literal: "."))
        }
    }
    
    func processEmphasis(_ stackBottom: Delimiter?) {
        var closer = self.lastDelim
        var openersBottomIndex: Int = 0
        var openersBottom: [Delimiter?] = [stackBottom, stackBottom, stackBottom,
                                           stackBottom, stackBottom, stackBottom]
        
        // move back to first relevant delim.
        while let theCloser = closer, theCloser.previous !== stackBottom {
            closer = theCloser.previous
        }
        
        // now move forward, looking for closers, and handling each
        while let theCloser = closer {
            if theCloser.canClose {
                switch theCloser.delimChar {
                case "\"":
                    openersBottomIndex = 0
                case "'":
                    openersBottomIndex = 1
                case "_":
                    openersBottomIndex = 2
                case "*":
                    openersBottomIndex = 3 + (theCloser.length % 3)
                default:
                    fatalError()
                }
                
                // Now look backwards for first matching opener:
                var opener = theCloser.previous
                var openerFound = false
                while let theOpener = opener, theOpener !== openersBottom[openersBottomIndex] {
                    if theOpener.canOpen && theOpener.delimChar == theCloser.delimChar {
                        // interior closer of size 2 can't match opener of size 1
                        // or of size 1 can't match 2
                        if !(theCloser.canOpen || theOpener.canClose) ||
                            ((theOpener.length + theCloser.length) % 3) != 0 {
                            openerFound = true
                            break
                        }
                    }
                    opener = theOpener.previous
                }
                let oldCloser = theCloser
                if theCloser.delimChar == "*" || theCloser.delimChar == "_" {
                    if openerFound {
                        closer = self.S_insert_emph(opener!, theCloser)
                    } else {
                        closer = theCloser.next
                    }
                } else if theCloser.delimChar == "\'" {
                    theCloser.inlText?.asLiteral?.free()
                    theCloser.inlText?.asType = .literal(CmarkChunk(literal: RIGHTSINGLEQUOTE))
                    if openerFound {
                        opener?.inlText?.asLiteral?.free()
                        opener?.inlText?.asType = .literal(CmarkChunk(literal: LEFTSINGLEQUOTE))
                    }
                    closer = theCloser.next
                } else if theCloser.delimChar == "\"" {
                    closer?.inlText?.asLiteral?.free()
                    closer?.inlText?.asType = .literal(CmarkChunk(literal: RIGHTDOUBLEQUOTE))
                    if openerFound {
                        opener?.inlText?.asLiteral?.free()
                        opener?.inlText?.asType = .literal(CmarkChunk(literal: LEFTDOUBLEQUOTE))
                    }
                    closer = theCloser.next
                }
                if !openerFound {
                    // set lower bound for future searches for openers
                    openersBottom[openersBottomIndex] = oldCloser.previous
                    if !oldCloser.canOpen {
                        // we can remove a closer that can't be an
                        // opener, once we've seen there's no
                        // matching opener:
                        self.remove(oldCloser)
                    }
                }
            } else {
                closer = theCloser.next
            }
        }
        // free all delimiters in list until stack_bottom:
        while lastDelim != nil && lastDelim !== stackBottom {
            self.remove(lastDelim)
        }
    }
    
    private func S_insert_emph(_ opener: Delimiter,
                               _ closer: Delimiter) -> Delimiter? {
        var resultCloser: Delimiter? = closer
        let openerInl = opener.inlText!
        let closerInl = closer.inlText!
        var openerNumChars = openerInl.asLiteral!.len
        var closerNumChars = closerInl.asLiteral!.len
        
        // calculate the actual number of characters used from this closer
        let useDelim = (closerNumChars >= 2 && openerNumChars >= 2) ? 2 : 1
        
        // remove used characters from associated inlines.
        openerNumChars -= useDelim
        closerNumChars -= useDelim
        openerInl.asLiteral?.len = openerNumChars
        closerInl.asLiteral?.len = closerNumChars
        
        // free delimiters between opener and closer
        var delim = closer.previous
        while let theDelim = delim, theDelim !== opener {
            let tmpDelim = theDelim.previous
            self.remove(theDelim)
            delim = tmpDelim
        }
        
        // create new emph or strong, and splice it in to our inlines
        // between the opener and closer
        let emph = useDelim == 1 ? makeEmph() : makeStrong()
        
        var tmp = openerInl.next
        while let temp = tmp, temp !== closerInl {
            let tmpnext = temp.next
            emph.append(child: temp)
            tmp = tmpnext
        }
        openerInl.insertAfterMe(emph)
        
        emph.startLine = self.line
        emph.endLine = self.line
        emph.startColumn = openerInl.startColumn + self.columnOffset
        emph.endColumn = closerInl.endColumn + self.columnOffset
        
        // if opener has 0 characters, remove it and its associated inline
        if openerNumChars == 0 {
            openerInl.free()
            self.remove(opener)
        }
        
        // if closer has 0 characters, remove it and its associated inline
        if closerNumChars == 0 {
            // remove empty closer inline
            closerInl.free()
            // remove closer from list
            let tmpDelim = closer.next
            self.remove(closer)
            resultCloser = tmpDelim
        }
        
        return resultCloser
    }
    
    // Parse backslash-escape or just a backslash, returning an inline.
    fileprivate func handleBackslash() -> CmarkNode {
        advance()
        let nextchar = peekChar()
        if nextchar.isPunct { // only ascii symbols and newline can be escaped
            advance()
            return makeStr(pos - 2, pos - 1, input.dup(pos: pos - 1, len: 1))
        } else if !isEof && skipLineEnd() {
            return makeLinebreak()
        } else {
            return makeStr(pos - 1, pos - 1, CmarkChunk(literal: "\\"))
        }
    }
    
    // Parse an entity or a regular "&" string.
    // Assumes the subject has an '&' character at the current position.
    fileprivate func handleEntity() -> CmarkNode {
        let ent = CmarkStrbuf()
        
        advance()
        
        let len = ent.unescapedEnt(input.data + pos,
                                   input.len - pos)
        
        if len == 0 {
            return makeStr(pos - 1, pos - 1, CmarkChunk(literal: "&"))
        }
        
        pos += len
        return makeStr(pos - 1 - len, pos - 1, ent.bufDetach())
    }
}
extension CmarkChunk {
    // Clean a URL: remove surrounding whitespace, and remove \ that escape
    // punctuation.
    func cleanUrl() -> CmarkChunk {
        let buf = CmarkStrbuf()
        
        trim()
        
        if len == 0 {
            let result = CMARK_CHUNK_EMPTY
            return result
        }
        
        buf.unescapeHtmlF(data, len)
        
        buf.unescape()
        return buf.bufDetach()
    }
    
    func cleanTitle() -> CmarkChunk {
        let buf = CmarkStrbuf()
        
        if len == 0 {
            let result = CMARK_CHUNK_EMPTY
            return result
        }
        
        let first = data[0]
        let last = data[len - 1]
        
        // remove surrounding quotes if any:
        if (first == "'" && last == "'") || (first == "(" && last == ")") ||
            (first == "\"" && last == "\"") {
            buf.unescapeHtmlF(data + 1, len - 2)
        } else {
            buf.unescapeHtmlF(data, len)
        }
        
        buf.unescape()
        return buf.bufDetach()
    }
}

extension Subject {
    // Parse an autolink or HTML tag.
    // Assumes the subject has a '<' character at the current position.
    fileprivate func handlePointyBrace(_ options: CmarkOptions) -> CmarkNode {
        var matchlen = 0
        
        advance() // advance past first <
        
        // first try to match a URL autolink
        matchlen = input.scanAutolinkUri(pos)
        if matchlen > 0 {
            let contents = input.dup(pos: pos, len: matchlen - 1)
            pos += matchlen
            
            return makeAutolink(pos - 1 - matchlen, pos - 1, contents, false)
        }
        
        // next try to match an email autolink
        matchlen = input.scanAutolinkEmail(pos)
        if matchlen > 0 {
            let contents = input.dup(pos: pos, len: matchlen - 1)
            pos += matchlen
            
            return makeAutolink(pos - 1 - matchlen, pos - 1, contents, true)
        }
        
        // finally, try to match an html tag
        matchlen = input.scanHtmlTag(pos)
        if matchlen > 0 {
            let contents = input.dup(pos: pos - 1, len: matchlen + 1)
            pos += matchlen
            let node = makeRawHtml(pos - matchlen - 1, pos - 1, contents)
            adjustSubjNodeNewlines(node, matchlen, 1, options)
            return node
        }
        
        // if nothing matches, just return the opening <:
        return makeStr(pos - 1, pos - 1, CmarkChunk(literal: "<"))
    }
    
    // Parse a link label.  Returns 1 if successful.
    // Note:  unescaped brackets are not allowed in labels.
    // The label begins with `[` and ends with the first `]` character
    // encountered.  Backticks in labels do not start code spans.
    func linkLabel() -> CmarkChunk? {
        let startpos = pos
        var length: Int = 0
        var c: UInt8 = 0
        
        // advance past [
        if peekChar() == "[" {
            advance()
        } else {
            return nil
        }
        
        noMatchOnBreak: do {
            while true {
                c = peekChar()
                guard c != 0 && c != "[" && c != "]" else {break}
                if c == "\\" {
                    advance()
                    length += 1
                    if peekChar().isPunct {
                        advance()
                        length += 1
                    }
                } else {
                    advance()
                    length += 1
                }
                if length > MAX_LINK_LABEL_LENGTH {
                    break noMatchOnBreak
                }
            }
            
            if c == "]" {
                let rawLabel = input.dup(pos: startpos + 1, len: pos - (startpos + 1))
                rawLabel.trim()
                advance() // advance past ]
                return rawLabel
            }
        } //### noMatchOnBreak
        
        pos = startpos // rewind
        return nil
    }
}

extension CmarkChunk {
    @discardableResult
    private func manualScanLinkUrl2(_ offset: Int, _ output: CmarkChunk) -> Int {
        var i = offset
        var nbP = 0
        
        while i < len {
            if data[i] == "\\" &&
                i + 1 < len &&
                data[i+1].isPunct {
                i += 2
            } else if data[i] == "(" {
                nbP += 1
                i += 1
                if nbP > 32 {
                    return -1
                }
            } else if data[i] == ")" {
                if nbP == 0 {
                    break
                }
                nbP -= 1
                i += 1
            } else if data[i].isSpace {
                break
            } else {
                i += 1
            }
        }
        
        if i >= len {
            return -1
        }
        
        output.initialize(data: data + offset, len: i - offset)
        return i - offset
    }
    
    func manualScanLinkUrl(offset: Int, output: CmarkChunk) -> Int {
        var i = offset
        
        if i < len && data[i] == "<" {
            i += 1
            while i < len {
                if data[i] == ">" {
                    i += 1
                    break
                } else if data[i] == "\\" {
                    i += 2
                } else if data[i].isSpace || data[i] == "<" {
                    return manualScanLinkUrl2(offset, output)
                } else {
                    i += 1
                }
            }
        } else {
            return manualScanLinkUrl2(offset, output)
        }
        
        if i >= len {
            return -1
        }
        
        output.initialize(data: data + offset + 1, len: i - 2 - offset)
        return i - offset
    }
}

extension Subject {
    // Return a link, an image, or a literal close bracket.
    fileprivate func handleCloseBracket() -> CmarkNode? {
        var ref: CmarkReference? = nil
        let urlChunk = CmarkChunk()
        var url: CmarkChunk = CmarkChunk()
        var title: CmarkChunk = CmarkChunk()
        
        advance() // advance past ]
        let initialPos = pos
        
        // get last [ or ![
        guard let opener = lastBracket else {
            
            return makeStr(pos - 1, pos - 1, CmarkChunk(literal: "]"))
        }
        
        if !opener.active {
            // take delimiter off stack
            popBracket()
            return makeStr(pos - 1, pos - 1, CmarkChunk(literal: "]"))
        }
        
        // If we got here, we matched a potential link/image text.
        // Now we check to see if it's a link/image.
        let isImage = opener.image
        
        let afterLinkTextPos = pos
        
        enum Label {case match; case noMatch}
        var gotoLabel: Label = .match
        matchNoMatch: do {
            // First, look for an inline link.
            if peekChar() == "(",
                case let sps = input.scanSpacechars(pos + 1), sps > -1,
                case let n = input.manualScanLinkUrl(offset: pos + 1 + sps,
                                                     output: urlChunk), n > -1 {
                
                // try to parse an explicit link:
                let endurl = pos + 1 + sps + n
                let starttitle = endurl + input.scanSpacechars(endurl)
                
                // ensure there are spaces btw url and title
                let endtitle = starttitle == endurl
                    ? starttitle
                    : starttitle + input.scanLinkTitle(starttitle)
                
                let endall = endtitle + input.scanSpacechars(endtitle)
                
                if peek(at: endall) == ")" {
                    pos = endall + 1
                    
                    let titleChunk =
                        input.dup(pos: starttitle, len: endtitle - starttitle)
                    url = urlChunk.cleanUrl()
                    title = titleChunk.cleanTitle()
                    urlChunk.free()
                    titleChunk.free()
                    gotoLabel = .match
                    break matchNoMatch
                    
                } else {
                    // it could still be a shortcut reference link
                    pos = afterLinkTextPos
                }
            }
            
            // Next, look for a following [link label] that matches in refmap.
            // skip spaces
            var rawLabel = linkLabel()
            if rawLabel == nil {
                // If we have a shortcut reference link, back up
                // to before the spacse we skipped.
                pos = initialPos
            }
            
            if (rawLabel == nil || rawLabel!.len == 0) && !opener.bracketAfter {
                rawLabel?.free()
                rawLabel = input.dup(pos: opener.position,
                                     len: initialPos - opener.position - 1)
            }
            
            if let rawLabel = rawLabel {
                
                ref = refmap?.lookup(rawLabel)
                rawLabel.free()
            }
            
            if let ref = ref { // found
                url = ref.url!.clone()
                title = ref.title!.clone()
                gotoLabel = .match
                break matchNoMatch
            } else {
                gotoLabel = .noMatch
                break matchNoMatch
            }
        }
        
        switch gotoLabel {
        case .noMatch:
            // If we fall through to here, it means we didn't match a link:
            popBracket() // remove this opener from delimiter list
            pos = initialPos
            return makeStr(pos - 1, pos - 1, CmarkChunk(literal: "]"))
            
        case .match:
            let inl = CmarkNode(simple: isImage ? .image : .link)
            let link = CmarkLink(url: url, title: title)
            inl.asType = .link(link)
            inl.startLine = line
            inl.endLine = line
            inl.startColumn = opener.inlText?.startColumn ?? 0
            inl.endColumn = pos + columnOffset + blockOffset
            opener.inlText?.insertBeforeMe(inl)
            // Add link text:
            var tmp = opener.inlText?.next
            while let theNode = tmp {
                let tmpnext = theNode.next
                inl.append(child: theNode)
                tmp = tmpnext
            }
            
            // Free the bracket [:
            opener.inlText?.free()
            
            processEmphasis(opener.previousDelimiter)
            popBracket()
            
            // Now, if we have a link, we also want to deactivate earlier link
            // delimiters. (This code can be removed if we decide to allow links
            // inside links.)
            if !isImage {
                var opener = lastBracket
                while let theOpener = opener {
                    if !theOpener.image {
                        if !theOpener.active {
                            break
                        } else {
                            theOpener.active = false
                        }
                    }
                    opener = theOpener.previous
                }
            }
            
            return nil
        }
    }
    
    // Parse a hard or soft linebreak, returning an inline.
    // Assumes the subject has a cr or newline at the current position.
    fileprivate func handleNewline() -> CmarkNode {
        let nlpos = pos
        // skip over cr, crlf, or lf:
        if peek(at: pos) == "\r" {
            advance()
        }
        if peek(at: pos) == "\n" {
            advance()
        }
        line += 1
        columnOffset = -pos
        // skip spaces at beginning of line
        skipSpaces()
        if nlpos > 1 && peek(at: nlpos - 1) == " " &&
            peek(at: nlpos - 2) == " " {
            return makeLinebreak()
        } else {
            return makeSoftbreak()
        }
    }
    
    fileprivate func findSpecialChar(_ options: CmarkOptions) -> Int {
        // "\r\n\\`&_*[]<!"
        let SPECIAL_CHARS: [Int8] = [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1,
            1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        ]
        
        // " ' . -
        let SMART_PUNCT_CHARS: [CChar] = [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            ]
        
        var n = pos + 1
        
        while n < input.len {
            if SPECIAL_CHARS[Int(input.data[n])] != 0 {
                return n
            }
            if options.contains(.smart) && SMART_PUNCT_CHARS[Int(input.data[n])] != 0 {
                return n
            }
            n += 1
        }
        
        return input.len
    }
    
    // Parse an inline, advancing subject, and add it as a child of parent.
    // Return 0 if no inline can be parsed, 1 otherwise.
    func parseInline(_ parent: CmarkNode, _ options: CmarkOptions) -> Bool {
        var newInl: CmarkNode? = nil
        let c = peekChar()
        if c == 0 {
            return false
        }
        switch c {
        case "\r", "\n":
            newInl = handleNewline()
        case "`":
            newInl = handleBackticks(options)
        case "\\":
            newInl = handleBackslash()
        case "&":
            newInl = handleEntity()
        case "<":
            newInl = handlePointyBrace(options)
        case "*", "_", "'", "\"":
            newInl = handleDelim(c, options.contains(.smart))
        case "-":
            newInl = handleHyphen(options.contains(.smart))
        case ".":
            newInl = handlePeriod(options.contains(.smart))
        case "[":
            advance()
            newInl = makeStr(pos - 1, pos - 1, CmarkChunk(literal: "["))
            pushBracket(image: false, inlText: newInl!)
        case "]":
            newInl = handleCloseBracket()
        case "!":
            advance()
            if peekChar() == "[" {
                advance()
                newInl = makeStr(pos - 2, pos - 1, CmarkChunk(literal: "!["))
                pushBracket(image: true, inlText: newInl!)
            } else {
                newInl = makeStr(pos - 1, pos - 1, CmarkChunk(literal: "!"))
            }
        default:
            let endpos = findSpecialChar(options)
            let contents = input.dup(pos: pos, len: endpos - pos)
            let startpos = pos
            pos = endpos
            
            // if we're at a newline, strip trailing spaces.
            if peekChar().isLineEnd {
                contents.rtrim()
            }
            
            newInl = makeStr(startpos, endpos - 1, contents)
        }
        if let newInl = newInl {
            parent.append(child: newInl)
        }
        
        return true
    }
}

extension CmarkNode {
    // Parse inlines from parent's string_content, adding as children of parent.
    func parseInlines(_ refmap: CmarkReferenceMap, _ options: CmarkOptions) {
        let content = CmarkChunk(content: self.content)
        let subj = Subject(lineNumber: startLine, blockOffset: startColumn - 1 + internalOffset, chunk: content, refmap: refmap)
        subj.input.rtrim()
        
        while !subj.isEof && subj.parseInline(self, options) {}
        
        subj.processEmphasis(nil)
        // free bracket and delim stack
        while let delim = subj.lastDelim {
            subj.remove(delim)
        }
        while subj.lastBracket != nil {
            subj.popBracket()
        }
    }
}

extension Subject {
    func spnl() {
        skipSpaces()
        if skipLineEnd() {
            skipSpaces()
        }
    }
}
//
extension CmarkChunk {
    // Parse reference.  Assumes string begins with '[' character.
    // Modify refmap if a reference is encountered.
    // Return 0 if no reference found, otherwise position of subject
    // after reference is parsed.
    func parseReferenceInline(_ refmap: CmarkReferenceMap) -> Int {
        
        let url = CmarkChunk()
        
        let subj = Subject(lineNumber: -1, blockOffset: 0, chunk: self, refmap: nil)
        
        // parse label:
        guard let lab = subj.linkLabel(), lab.len != 0 else {
            return 0
        }
        
        // colon:
        if subj.peekChar() == ":" {
            subj.advance()
        } else {
            return 0
        }
        
        // parse link url:
        subj.spnl()
        if case let matchlen = subj.input.manualScanLinkUrl(offset: subj.pos, output: url), matchlen > -1, url.len > 0 {
            subj.pos += matchlen
        } else {
            return 0
        }
        
        // parse optional link_title
        let beforetitle = subj.pos
        subj.spnl()
        let matchlen = subj.input.scanLinkTitle(subj.pos)
        let title: CmarkChunk
        if matchlen > 0 {
            title = subj.input.dup(pos: subj.pos, len: matchlen)
            subj.pos += matchlen
        } else {
            subj.pos = beforetitle
            title = CmarkChunk(literal: "")
        }
        
        // parse final spaces and newline:
        subj.skipSpaces()
        if !subj.skipLineEnd() {
            if matchlen > 0 { // try rewinding before title
                subj.pos = beforetitle
                subj.skipSpaces()
                if !subj.skipLineEnd() {
                    return 0
                }
            } else {
                return 0
            }
        }
        // insert reference into refmap
        refmap.create(label: lab, url: url, title: title)
        return subj.pos
    }
}
