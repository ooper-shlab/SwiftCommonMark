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
    fileprivate func makeStr(_ sc: Int, _ ec: Int, _ s: StringChunk) -> CmarkNode {
        return makeLiteral(.text, sc, ec, s)
    }
    fileprivate func makeStr(_ startIndex: String.Index, _ endIndex: String.Index, _ s: StringChunk) -> CmarkNode {
        return makeLiteral(.text, startIndex, endIndex, s)
    }
    fileprivate func makeCode(_ sc: Int, _ ec: Int, _ s: StringChunk) -> CmarkNode {
        return makeLiteral(.code, sc, ec, s)
    }
    fileprivate func makeCode(_ startIndex: String.Index, _ endIndex: String.Index, _ s: StringChunk) -> CmarkNode {
        return makeLiteral(.code, startIndex, endIndex, s)
    }
    fileprivate func makeRawHtml(_ sc: Int, _ ec: Int, _ s: StringChunk) -> CmarkNode {
        return makeLiteral(.htmlInline, sc, ec, s)
    }
    fileprivate func makeRawHtml(_ startIndex: String.Index, _ endIndex: String.Index, _ s: StringChunk) -> CmarkNode {
        return makeLiteral(.htmlInline, startIndex, endIndex, s)
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
    var delimChar: UnicodeScalar = "\0"
    var canOpen: Bool = false
    var canClose: Bool = false
}

class Bracket {
    var previous: Bracket?
    var previousDelimiter: Delimiter?
    var inlText: CmarkNode?
    var index: String.Index
    var image: Bool = false
    var active: Bool = false
    var bracketAfter: Bool = false
    
    init(index: String.Index) {
        self.index = index
    }
}

class Subject {
    var input: StringChunk
    var line: Int = 0
    var curIndex: String.Index
    var blockOffset: Int = 0
    var columnOffset: Int = 0
    var refmap: CmarkReferenceMap?
    var lastDelim: Delimiter?
    var lastBracket: Bracket?
    var backticks: [String.Index?] = Array(repeating: nil, count: MAXBACKTICKS+1)
    var scannedForBackticks: Bool = false
    
    init(input: StringChunk, refmap: CmarkReferenceMap?) {
        self.input = input
        self.curIndex = input.startIndex
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
                             _ s: StringChunk) -> CmarkNode {
        let e = CmarkNode(t)
        e.asType = .literal(s)
        e.startLine = line
        e.endLine = line
        // columns are 1 based.
        e.startColumn = startColumn + 1 + columnOffset + blockOffset
        e.endColumn = endColumn + 1 + columnOffset + blockOffset
        return e
    }
    private func makeLiteral(_ t: CmarkNodeType,
                             _ startIndex: String.Index, _ endIndex: String.Index,
                             _ s: StringChunk) -> CmarkNode {
        //###TODO: This consumes CPU time in huge lines...
        let startColumn = self.distance(from: input.startIndex, to: startIndex)
        let endColumn = self.distance(from: startIndex, to: endIndex) + startColumn
        return makeLiteral(t, startColumn, endColumn, s)
    }
}

extension CmarkNode {
    // Create an inline with no value.
    convenience init(simple t: CmarkNodeType) {
        self.init(tag: t, content: StringBuffer(capacity: 0), flags: [])
    }
}

extension Subject {
    // Like make_str, but parses entities.
    fileprivate func makeStrWithEntities(
        _ startColumn: Int, _ endColumn: Int,
        _ content: StringChunk) -> CmarkNode {
        let unescaped = StringBuffer()
        
        if unescaped.unescapeHtml(content) {
            return makeStr(startColumn, endColumn, unescaped.bufDetach())
        } else {
            return makeStr(startColumn, endColumn, content)
        }
    }
}

extension StringChunk {
    // Duplicate a chunk by creating a copy of the buffer not by reusing the
    // buffer like cmark_chunk_dup does.
    fileprivate func clone() -> StringChunk {
        
        let c = StringChunk(string, startIndex, endIndex)
        
        return c
    }
}

private func cmark_clean_autolink(_ url: StringChunk,
                                  _ isEmail: Bool) -> StringChunk {
    let buf = StringBuffer()
    
    url.trim()
    
    if url.len == 0 {
        let result = STRING_CHUNK_EMPTY
        return result
    }
    
    if isEmail {
        buf.puts("mailto:")
    }
    
    buf.unescapeHtmlF(url)
    return buf.bufDetach()
}

extension Subject {
    fileprivate func makeAutolink(
        _ startColumn: Int, _ endColumn: Int,
        _ url: StringChunk, _ isEmail: Bool) -> CmarkNode {
        let link = CmarkNode(simple: .link)
        let linkUrl = cmark_clean_autolink(url, isEmail)
        let title = StringChunk(literal: "")
        let clink = CmarkLink(url: linkUrl, title: title)
        link.asType = .link(clink)
        link.startLine = line
        link.endLine = line
        link.startColumn = startColumn + 1
        link.endColumn = endColumn + 1
        link.append(child: makeStrWithEntities(startColumn + 1, endColumn - 1, url))
        return link
    }
    fileprivate func makeAutolink(
        _ startIndex: String.Index, _ endIndex: String.Index,
        _ url: StringChunk, _ isEmail: Bool) -> CmarkNode {
        //###TODO: This consumes CPU time in huge lines...
        let startColumn = self.distance(from: self.input.startIndex, to: startIndex)
        let endColumn = startColumn + self.distance(from: startIndex, to: endIndex)
        return makeAutolink(startColumn, endColumn, url, isEmail)
    }
    
    convenience init(lineNumber: Int, blockOffset: Int, chunk: StringChunk, refmap: CmarkReferenceMap?) {
        self.init(input: chunk, refmap: refmap)
        self.line = lineNumber
        self.curIndex = input.startIndex
        self.blockOffset = blockOffset
        self.columnOffset = 0
        self.lastDelim = nil
        self.lastBracket = nil
        for i in 0...MAXBACKTICKS {
            self.backticks[i] = nil
        }
        self.scannedForBackticks = false
    }
}

private func isbacktick(_ c: UnicodeScalar) -> Bool {return c == "`"}

extension Subject {
    func peekChar() -> UnicodeScalar {
        // NULL bytes should have been stripped out by now.  If they're
        // present, it's a programming error:
        assert(!(curIndex < input.endIndex && input[curIndex] == "\0"))
        return curIndex < input.endIndex ? input[curIndex] : "\0"
    }
    
//    fileprivate func peek(at pos: Int) -> UnicodeScalar {
//        return input[pos]
//    }
    
    fileprivate func peek(at index: String.Index) -> UnicodeScalar {
        return input[index]
    }
    
    fileprivate func peek(at index: String.Index, offset: Int) -> UnicodeScalar {
        return input[input.index(index, offsetBy: offset)]
    }
    
    fileprivate func index(after index: String.Index) -> String.Index {
        return input.index(after: index)
    }
    
    fileprivate func indexAfter() -> String.Index {
        return input.index(after: self.curIndex)
    }
    
    fileprivate func index(before index: String.Index) -> String.Index {
        return input.index(before: index)
    }
    
    fileprivate func indexBefore() -> String.Index {
        return input.index(before: self.curIndex)
    }
    
    fileprivate func index(_ index: String.Index, offsetBy: Int) -> String.Index {
        return input.index(index, offsetBy: offsetBy)
    }
    
    fileprivate func index(offsetBy: Int) -> String.Index {
        return input.index(self.curIndex, offsetBy: offsetBy)
    }
    
    fileprivate func distance(from: String.Index, to: String.Index) -> Int {
        return input.distance(from: from, to: to)
    }
    fileprivate func distance(from: String.Index) -> Int {
        return input.distance(from: from, to: self.curIndex)
    }
    fileprivate func distance(to: String.Index) -> Int {
        return input.distance(from: self.curIndex, to: to)
    }
    
    fileprivate func position(_ index: String.Index) -> Int {
        return input.distance(from: input.startIndex, to: index)
    }
    fileprivate func position() -> Int {
        return input.distance(from: input.startIndex, to: self.curIndex)
    }
    
    // Return true if there are more characters in the subject.
    var isEof: Bool {
        return curIndex >= input.endIndex
    }
    
    // Advance the subject.  Doesn't check for eof.
    func advance() {curIndex = indexAfter()}
    ///### offset: valid UTF-8 offset
    func advance(_ offset: Int) {
        curIndex = input.index(curIndex, offsetBy: offset)
    }
    func advance(to index: String.Index) {
        self.curIndex = index
    }
    
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
    fileprivate func takeWhile(_ f: (UnicodeScalar)->Bool) -> StringChunk {
        let start = curIndex
        
        while case let c = peekChar(), f(c) {
            advance()
        }
        
        return input.dup(start, curIndex)
    }
    
    // Return the number of newlines in a given span of text in a subject.  If
    // the number is greater than zero, also return the number of characters
    // between the last newline and the end of the span in `since_newline`.
    fileprivate func countNewlines(from _from: Int, len _len: Int, sinceNewline: inout Int) -> Int {
        var from = _from
        var len = _len
        var nls = 0
        var sinceNl = 0
        
        //###TODO: accessing repeatedly with UTF-8 index is not efficient
        while len != 0 {
            let c = input[from]
            len -= c.size
            if c == "\n" {
                nls += 1
                sinceNl = 0
            } else {
                sinceNl += c.size
            }
            from += c.size
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
        //###TODO: should update countNewlines()?
        let pos = self.distance(from: input.startIndex)
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
        _ openticklength: Int) -> String.Index? {
        
        if openticklength > MAXBACKTICKS {
            // we limit backtick string length because of the array subj->backticks:
            return nil
        }
        if scannedForBackticks, let backticksIndex = backticks[openticklength],
            backticksIndex <= curIndex {
            // return if we already know there's no closer
            return nil
        }
        while true {
            // read non backticks
            while case let c = peekChar(), c != "\0", c != "`" {
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
                backticks[numticks] = index(curIndex, offsetBy: -numticks)
            }
            if numticks == openticklength {
                return curIndex
            }
        }
        // got through whole input without finding closer
        scannedForBackticks = true
        return nil
    }
    
    // Parse backtick code section or raw backticks, return an inline.
    // Assumes that the subject has a backtick at the current position.
    fileprivate func handleBackticks(_ options: CmarkOptions) -> CmarkNode {
        let openticks = takeWhile(isbacktick)
        let startindex = curIndex
        let endindex = scanToClosingBackticks(openticks.len)
        
        if endindex == nil {      // not found
            curIndex = startindex // rewind
            return makeStr(curIndex, curIndex, openticks)
        } else {
            let buf = StringBuffer()
            
            buf.set(input.string, from: startindex, to: index(endindex!, offsetBy: -openticks.len))
            buf.trim()
            buf.normalizeWhitespace()
            
            let end = index(endindex!, offsetBy: -openticks.len - 1)
            let node = makeCode(startindex, end, buf.bufDetach())
            let matchlen = distance(from: startindex, to: endindex!)
            adjustSubjNodeNewlines(node, matchlen, openticks.len, options)
            return node
        }
    }
    
    // Scan ***, **, or * and return number scanned, or 0.
    // Advances position.
    fileprivate func scanDelims(_ c: UnicodeScalar, canOpen: inout Bool,
                                canClose: inout Bool) -> Int {
        var numdelims = 0
        var afterChar: UnicodeScalar = "\0"
        var beforeChar: UnicodeScalar = "\0"
        
        if curIndex == input.startIndex {
            beforeChar = "\n"
        } else {
            beforeChar = peek(at: indexBefore())
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
        
        if curIndex < input.endIndex {
            afterChar = peekChar()
        } else {
            afterChar = "\n"
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
                beforeChar != "]" && beforeChar != ")"
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
    
    fileprivate func pushDelimiter(_ c: UnicodeScalar, canOpen: Bool,
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
        let b = Bracket(index: curIndex)
        if let bracket = lastBracket {
            bracket.bracketAfter = true
        }
        b.image = image
        b.active = true
        b.inlText = inlText
        b.previous = lastBracket
        b.previousDelimiter = lastDelim
        //b.position = distance(from: input.startIndex)
        b.bracketAfter = false
        lastBracket = b
    }
    
    // Assumes the subject has a c at the current position.
    fileprivate func handleDelim(_ c: UnicodeScalar, _ smart: Bool) -> CmarkNode {
        var canOpen: Bool = false, canClose: Bool = false
        let contents: StringChunk
        
        let numdelims = scanDelims(c, canOpen: &canOpen, canClose: &canClose)
        
        let start = index(curIndex, offsetBy: -numdelims)
        if c == "'" && smart {
            contents = StringChunk(literal: RIGHTSINGLEQUOTE)
        } else if c == "\"" && smart {
            contents =
                StringChunk(literal: canClose ? RIGHTDOUBLEQUOTE : LEFTDOUBLEQUOTE)
        } else {
            contents = input.dup(start, curIndex)
        }
        
        let inlText = makeStr(start, indexBefore(), contents)
        
        if (canOpen || canClose) && (!(c == "'" || c == "\"") || smart) {
            pushDelimiter(c, canOpen: canOpen, canClose: canClose, inlText: inlText)
        }
        
        return inlText
    }
    
    // Assumes we have a hyphen at the current position.
    fileprivate func handleHyphen(_ smart: Bool) -> CmarkNode {
        let startindex = curIndex
        
        advance()
        
        if !smart || peekChar() != "-" {
            let before = indexBefore()
            return makeStr(before, before, StringChunk(literal: "-"))
        }
        
        while smart && peekChar() == "-" {
            advance()
        }
        
        let numhyphens = distance(from: startindex)
        var enCount = 0
        var emCount = 0
        let buf = StringBuffer()
        
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
        
        let before = indexBefore()
        return makeStr(startindex, before, buf.bufDetach())
    }
    
    // Assumes we have a period at the current position.
    fileprivate func handlePeriod(_ smart: Bool) -> CmarkNode {
        advance()
        if smart && peekChar() == "." {
            advance()
            if peekChar() == "." {
                advance()
                let pos_3 = index(offsetBy: -3)
                let pos_1 = index(offsetBy: -1)
                return makeStr(pos_3, pos_1, StringChunk(literal: ELLIPSES))
            } else {
                let pos_2 = index(offsetBy: -2)
                let pos_1 = index(offsetBy: -1)
                return makeStr(pos_2, pos_1, StringChunk(literal: ".."))
            }
        } else {
            let pos_1 = indexBefore()
            return makeStr(pos_1, pos_1, StringChunk(literal: "."))
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
                    theCloser.inlText?.asType = .literal(StringChunk(literal: RIGHTSINGLEQUOTE))
                    if openerFound {
                        opener?.inlText?.asLiteral?.free()
                        opener?.inlText?.asType = .literal(StringChunk(literal: LEFTSINGLEQUOTE))
                    }
                    closer = theCloser.next
                } else if theCloser.delimChar == "\"" {
                    closer?.inlText?.asLiteral?.free()
                    closer?.inlText?.asType = .literal(StringChunk(literal: RIGHTDOUBLEQUOTE))
                    if openerFound {
                        opener?.inlText?.asLiteral?.free()
                        opener?.inlText?.asType = .literal(StringChunk(literal: LEFTDOUBLEQUOTE))
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
        openerInl.asLiteral?.truncate(openerNumChars)
        closerInl.asLiteral?.truncate(closerNumChars)
        
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
            let pos_2 = index(curIndex, offsetBy: -2)
            let pos_1 = index(curIndex, offsetBy: -1)
            return makeStr(pos_2, pos_1, input.dup(pos_1, curIndex))
        } else if !isEof && skipLineEnd() {
            return makeLinebreak()
        } else {
            let pos_1 = index(curIndex, offsetBy: -1)
            return makeStr(pos_1, pos_1, StringChunk(literal: "\\"))
        }
    }
    
    // Parse an entity or a regular "&" string.
    // Assumes the subject has an '&' character at the current position.
    fileprivate func handleEntity() -> CmarkNode {
        let ent = StringBuffer()
        
        advance()
        
        let len = ent.unescapedEnt(input.string, curIndex, input.endIndex)
        
        if len == 0 {
            let pos_1 = index(curIndex, offsetBy: -1)
            return makeStr(pos_1, pos_1, StringChunk(literal: "&"))
        }
        
        let pos_1_len = index(curIndex, offsetBy: -1)
        advance(len)
        let pos_1 = index(curIndex, offsetBy: -1)
        return makeStr(pos_1_len, pos_1, ent.bufDetach())
    }
}

extension StringChunk {
    // Clean a URL: remove surrounding whitespace, and remove \ that escape
    // punctuation.
    func cleanUrl() -> StringChunk {
        let buf = StringBuffer()
        
        trim()
        
        if isEmpty {
            let result = STRING_CHUNK_EMPTY
            return result
        }
        
        buf.unescapeHtmlF(self)
        
        buf.unescape()
        return buf.bufDetach()
    }
    
    func cleanTitle() -> StringChunk {
        let buf = StringBuffer()
        
        if isEmpty {
            let result = STRING_CHUNK_EMPTY
            return result
        }
        
        // remove surrounding quotes if any:
        if (first == "'" && last == "'") || (first == "(" && last == ")") ||
            (first == "\"" && last == "\"") {
            let usv = string.unicodeScalars
            buf.unescapeHtmlF(string, usv.index(after: startIndex), usv.index(before: endIndex))
        } else {
            buf.unescapeHtmlF(self)
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
        matchlen = input.scanAutolinkUri(curIndex)
        if matchlen > 0 {
            let start = indexBefore()
            let end = index(offsetBy: matchlen - 1)
            let contents = input.dup(curIndex, end)
            curIndex = index(after: end)
            
            return makeAutolink(start, end, contents, false)
        }
        
        // next try to match an email autolink
        matchlen = input.scanAutolinkEmail(curIndex)
        if matchlen > 0 {
            let start = indexBefore()
            let end = index(offsetBy: matchlen - 1)
            let contents = input.dup(curIndex, end)
            curIndex = index(after: end)
            
            return makeAutolink(start, end, contents, true)
        }
        
        // finally, try to match an html tag
        matchlen = input.scanHtmlTag(curIndex)
        if matchlen > 0 {
            let start = indexBefore()
            let end = index(offsetBy: matchlen)
            let contents = input.dup(start, end)
            curIndex = end
            let end2 = indexBefore()
            let node = makeRawHtml(start, end2, contents)
            adjustSubjNodeNewlines(node, matchlen, 1, options)
            return node
        }
        
        // if nothing matches, just return the opening <:
        let pos_1 = indexBefore()
        return makeStr(pos_1, pos_1, StringChunk(literal: "<"))
    }
    
    // Parse a link label.  Returns 1 if successful.
    // Note:  unescaped brackets are not allowed in labels.
    // The label begins with `[` and ends with the first `]` character
    // encountered.  Backticks in labels do not start code spans.
    func linkLabel() -> StringChunk? {
        let startindex = curIndex
        var length: Int = 0
        var c: UnicodeScalar = "\0"
        
        // advance past [
        if peekChar() == "[" {
            advance()
        } else {
            return nil
        }
        
        noMatchOnBreak: do {
            while true {
                c = peekChar()
                guard c != "\0" && c != "[" && c != "]" else {break}
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
                let start = index(after: startindex)
                let rawLabel = input.dup(start, curIndex)
                rawLabel.trim()
                advance() // advance past ]
                return rawLabel
            }
        } //### noMatchOnBreak
        
        curIndex = startindex // rewind
        return nil
    }
}

extension StringChunk {
    @discardableResult
    private func manualScanLinkUrl2(_ start: String.Index, _ output: StringChunk) -> Int {
        var i = start
        var nbP = 0
        let usv = string.unicodeScalars
        
        while i < endIndex {
            let i_1 = usv.index(after: i)
            if usv[i] == "\\" &&
                i_1 < endIndex &&
                usv[i_1].isPunct {
                i = usv.index(after: i_1)
            } else if usv[i] == "(" {
                nbP += 1
                i = i_1
                if nbP > 32 {
                    return -1
                }
            } else if usv[i] == ")" {
                if nbP == 0 {
                    break
                }
                nbP -= 1
                i = i_1
            } else if usv[i].isSpace {
                break
            } else {
                i = i_1
            }
        }
        
        if i >= endIndex {
            return -1
        }
        
        output.initialize(string, start, i)
        return distance(from: start, to: i)
    }
    
    func manualScanLinkUrl(_ startIndex: String.Index, offset: Int = 0, output: StringChunk) -> Int {
        let start = index(startIndex, offsetBy: offset)
        //var i = offset
        var i = start
        let usv = string.unicodeScalars
        
        if i < endIndex && usv[i] == "<" {
            i = usv.index(after: i)
            while i < endIndex {
                if usv[i] == ">" {
                    i = usv.index(after: i)
                    break
                } else if usv[i] == "\\" {
                    i = usv.index(i, offsetBy: 2)
                } else if usv[i].isSpace || usv[i] == "<" {
                    return manualScanLinkUrl2(start, output)
                } else {
                    i = usv.index(after: i)
                }
            }
        } else {
            return manualScanLinkUrl2(start, output)
        }
        
        if i >= endIndex {
            return -1
        }
        
        output.initialize(string, usv.index(after: start), usv.index(before: i))
        return distance(from: start, to: i)
    }
}

extension Subject {
    // Return a link, an image, or a literal close bracket.
    fileprivate func handleCloseBracket() -> CmarkNode? {
        var ref: CmarkReference? = nil
        let urlChunk = StringChunk()
        var url: StringChunk = StringChunk()
        var title: StringChunk = StringChunk()
        
        let start = curIndex
        advance() // advance past ]
        let initialindex = curIndex
        
        // get last [ or ![
        guard let opener = lastBracket else {
            
            return makeStr(start, start, StringChunk(literal: "]"))
        }
        
        if !opener.active {
            // take delimiter off stack
            popBracket()
            return makeStr(start, start, StringChunk(literal: "]"))
        }
        
        // If we got here, we matched a potential link/image text.
        // Now we check to see if it's a link/image.
        let isImage = opener.image
        
        let afterLinkTextIndex = curIndex
        
        enum Label {case match; case noMatch}
        var gotoLabel: Label = .match
        matchNoMatch: do {
            // First, look for an inline link.
            if peekChar() == "(",
                case let sps = input.scanSpacechars(curIndex, 1), sps > -1,
                case let n = input.manualScanLinkUrl(curIndex, offset: 1 + sps,
                                                     output: urlChunk), n > -1 {
                
                // try to parse an explicit link:
                let endurlindex = index(offsetBy: 1 + sps + n)
                let starttitleindex = index(endurlindex, offsetBy: input.scanSpacechars(endurlindex))
                
                // ensure there are spaces btw url and title
                let endtitleindex = starttitleindex == endurlindex
                    ? starttitleindex
                    : index(starttitleindex, offsetBy: input.scanLinkTitle(starttitleindex))
                
                let endallindex = index(endtitleindex, offsetBy: input.scanSpacechars(endtitleindex))
                
                if peek(at: endallindex) == ")" {
                    curIndex = index(after: endallindex)
                    
                    let titleChunk =
                        input.dup(starttitleindex, endtitleindex)
                    url = urlChunk.cleanUrl()
                    title = titleChunk.cleanTitle()
                    urlChunk.free()
                    titleChunk.free()
                    gotoLabel = .match
                    break matchNoMatch
                    
                } else {
                    // it could still be a shortcut reference link
                    curIndex = afterLinkTextIndex
                }
            }
            
            // Next, look for a following [link label] that matches in refmap.
            // skip spaces
            var rawLabel = linkLabel()
            if rawLabel == nil {
                // If we have a shortcut reference link, back up
                // to before the spacse we skipped.
                curIndex = initialindex
            }
            
            if (rawLabel == nil || rawLabel!.len == 0) && !opener.bracketAfter {
                rawLabel?.free()
                let end = input.index(before: initialindex)
                //let start = input.string.utf8.index(input.startIndex, offsetBy: opener.position)
                let start = opener.index
                rawLabel = input.dup(start,
                                     end)
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
            curIndex = initialindex
            let pos_1 = index(before: curIndex)
            return makeStr(pos_1, pos_1, StringChunk(literal: "]"))
            
        case .match:
            let inl = CmarkNode(simple: isImage ? .image : .link)
            let link = CmarkLink(url: url, title: title)
            inl.asType = .link(link)
            inl.startLine = line
            inl.endLine = line
            inl.startColumn = opener.inlText?.startColumn ?? 0
            let pos = distance(from: input.startIndex)
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
        let nlindex = curIndex
        // skip over cr, crlf, or lf:
        if peek(at: curIndex) == "\r" {
            advance()
        }
        if peek(at: curIndex) == "\n" {
            advance()
        }
        line += 1
        let pos = distance(from: input.startIndex)
        columnOffset = -pos
        // skip spaces at beginning of line
        skipSpaces()
        if distance(from: input.startIndex, to: nlindex) > 1 && peek(at: nlindex, offset: -1) == " " &&
            peek(at: nlindex, offset: -2) == " " {
            return makeLinebreak()
        } else {
            return makeSoftbreak()
        }
    }
    
    fileprivate func findSpecialChar(_ options: CmarkOptions) -> String.Index {
        // "\r\n\\`&_*[]<!"
        let SPECIAL_CHARS: [Int8] = [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1,
            1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            ]
        func isSpecialChar(_ ch: UnicodeScalar) -> Bool {
            return ch.value < 128 && SPECIAL_CHARS[Int(ch.value)] != 0
        }
        
        // " ' . -
        let SMART_PUNCT_CHARS: [Int8] = [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            ]
        func isSmartPunctChar(_ ch: UnicodeScalar) -> Bool {
            return ch.value < 128 && SMART_PUNCT_CHARS[Int(ch.value)] != 0
        }
        
        var n = indexAfter()
        
        while n < input.endIndex {
            if isSpecialChar(input[n]) {
                return n
            }
            if options.contains(.smart) && isSmartPunctChar(input[n]) {
                return n
            }
            n = index(after: n)
        }
        
        return input.endIndex
    }
    
    // Parse an inline, advancing subject, and add it as a child of parent.
    // Return 0 if no inline can be parsed, 1 otherwise.
    func parseInline(_ parent: CmarkNode, _ options: CmarkOptions) -> Bool {
        var newInl: CmarkNode? = nil
        let c = peekChar()
        if c == "\0" {
            return false
        }
        autoreleasepool{
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
                let pos_1 = index(offsetBy: -1)
                newInl = makeStr(pos_1, pos_1, StringChunk(literal: "["))
                pushBracket(image: false, inlText: newInl!)
            case "]":
                newInl = handleCloseBracket()
            case "!":
                advance()
                if peekChar() == "[" {
                    advance()
                    let pos_1 = index(offsetBy: -1)
                    let pos_2 = index(pos_1, offsetBy: -1)
                    newInl = makeStr(pos_2, pos_1, StringChunk(literal: "!["))
                    pushBracket(image: true, inlText: newInl!)
                } else {
                    let pos_1 = index(offsetBy: -1)
                    newInl = makeStr(pos_1, pos_1, StringChunk(literal: "!"))
                }
            default:
                let endindex = findSpecialChar(options)
                let contents = input.dup(curIndex, endindex)
                let startindex = curIndex
                curIndex = endindex
                
                // if we're at a newline, strip trailing spaces.
                if peekChar().isLineEnd {
                    contents.rtrim()
                }
                
                newInl = makeStr(startindex, index(before: endindex), contents)
            }
            if let newInl = newInl {
                parent.append(child: newInl)
            }
        }
        
        return true
    }
}

extension CmarkNode {
    // Parse inlines from parent's string_content, adding as children of parent.
    func parseInlines(_ refmap: CmarkReferenceMap, _ options: CmarkOptions) {
        let content = StringChunk(content: self.content)
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

extension StringChunk {
    // Parse reference.  Assumes string begins with '[' character.
    // Modify refmap if a reference is encountered.
    // Return 0 if no reference found, otherwise position of subject
    // after reference is parsed.
    func parseReferenceInline(_ refmap: CmarkReferenceMap) -> String.Index? {
        
        let url = StringChunk()
        
        let subj = Subject(lineNumber: -1, blockOffset: 0, chunk: self, refmap: nil)
        
        // parse label:
        guard let lab = subj.linkLabel(), lab.len != 0 else {
            return nil
        }
        
        // colon:
        if subj.peekChar() == ":" {
            subj.advance()
        } else {
            return nil
        }
        
        // parse link url:
        subj.spnl()
        if case let matchlen = subj.input.manualScanLinkUrl(subj.curIndex, output: url), matchlen > -1, !url.isEmpty {
            subj.advance(matchlen)
        } else {
            return nil
        }
        
        // parse optional link_title
        let beforetitle = subj.curIndex
        subj.spnl()
        let matchlen = subj.input.scanLinkTitle(subj.curIndex)
        let title: StringChunk
        if matchlen > 0 {
            let end = subj.index(subj.curIndex, offsetBy: matchlen)
            title = subj.input.dup(subj.curIndex, end)
            subj.advance(to: end)
        } else {
            subj.curIndex = beforetitle
            title = StringChunk(literal: "")
        }
        
        // parse final spaces and newline:
        subj.skipSpaces()
        if !subj.skipLineEnd() {
            if matchlen > 0 { // try rewinding before title
                subj.curIndex = beforetitle
                subj.skipSpaces()
                if !subj.skipLineEnd() {
                    return nil
                }
            } else {
                return nil
            }
        }
        // insert reference into refmap
        refmap.create(label: lab, url: url, title: title)
        return subj.curIndex
    }
}
