//
//  Commonmark.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/17.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on commonmark.c
 https://github.com/commonmark/cmark/blob/master/src/cmark_ctype.h
 
 Some comments moved from cmark.h
 https://github.com/commonmark/cmark/blob/master/src/cmark.h
 */

import Foundation

// Functions to convert cmark_nodes to commonmark strings.
private func outc(_ renderer: CmarkRenderer, _ escape: CmarkEscaping,
                  _ c: Int32, _ nextc: UInt8) {
    let followsDigit =
        renderer.buffer.size > 0 &&
            renderer.buffer.last!.isDigit
    
    let needsEscaping =
        c < 0x80 && escape != .literal &&
            ((escape == .normal &&
                (c == "*" || c == "_" || c == "[" || c == "]" || c == "#" || c == "<" ||
                    c == ">" || c == "\\" || c == "`" || c == "!" ||
                    (c == "&" && nextc.isAlpha) || (c == "!" && nextc == "[") ||
                    (renderer.beginContent && (c == "-" || c == "+" || c == "=") &&
                        // begin_content doesn't get set to false til we've passed digits
                        // at the beginning of line, so...
                        !followsDigit) ||
                    (renderer.beginContent && (c == "." || c == ")") && followsDigit &&
                        (nextc == 0 || nextc.isSpace)))) ||
                (escape == .url &&
                    (c == "`" || c == "<" || c == ">" || cmark_isspace(c) || c == "\\" ||
                        c == ")" || c == "(")) ||
                (escape == .title &&
                    (c == "`" || c == "<" || c == ">" || c == "\"" || c == "\\")))
    
    if needsEscaping {
        if cmark_isspace(c) {
            // use percent encoding for spaces
            let encoded = String(format: "%%%0x2", c)
            renderer.buffer.puts(encoded)
            renderer.column += 3
        } else {
            renderer.renderAscii("\\")
            renderer.renderCodePoint(c)
        }
    } else {
        renderer.renderCodePoint(c)
    }
}

private func longest_backtick_sequence(_ code: StringBufferType) -> Int {
    var longest = 0
    var current = 0
    var index = code.startIndex
    while index <= code.endIndex {
        if code[index] == "`" {
            current += 1
        } else {
            if current > longest {
                longest = current
            }
            current = 0
        }
        if index == code.endIndex {
            break
        }
        index = code.string.unicodeScalars.index(after: index)
    }
    return longest
}

private func shortest_unused_backtick_sequence(_ code: StringBufferType) -> Int {
    // note: if the shortest sequence is >= 32, this returns 32
    // so as not to overflow the bit array.
    var used: UInt32 = 1
    var current = 0
    var index = code.startIndex
    while index <= code.endIndex {
        if code[index] == "`" {
            current += 1
        } else {
            if current > 0 && current < 32 {
                used |= (1 << current)
            }
            current = 0
        }
        if index == code.endIndex {
            break
        }
        index = code.string.unicodeScalars.index(after: index)
    }
    // return number of first bit that is 0:
    var i = 0
    while i < 32 && (used & 1) != 0 {
        used >>= 1
        i += 1
    }
    return i
}

extension CmarkNode {
    fileprivate func isAutolink() -> Bool {
        
        if type != .link {
            return false
        }
        
        let url = asLink!.url
        if url.isEmpty || url.scanScheme(0) == 0 {
            return false
        }
        
        let title = asLink!.title
        // if it has a title, we can't treat it as an autolink:
        if !title.isEmpty {
            return false
        }
        
        guard let linkText = firstChild else {
            return false
        }
        linkText.consolidateTextNodes()
        var realurl = url.toString()
        if realurl.hasPrefix("mailto:") {
            realurl = String(realurl[realurl.index(realurl.startIndex, offsetBy: 7)...])
        }
        return realurl == linkText.asLiteral!.toString()
    }
    
    // if node is a block node, returns node.
    // otherwise returns first block-level node that is an ancestor of node.
    // if there is no block-level ancestor, returns NULL.
    fileprivate func getConainingBlock() -> CmarkNode? {
        var node: CmarkNode? = self
        while let theNode = node {
            if theNode.type.isBlock {
                return theNode
            } else {
                node = theNode.parent
            }
        }
        return nil
    }
}

private func S_render_node(_ renderer: CmarkRenderer, _ node: CmarkNode,
                           _ evType: CmarkEventType, _ options: CmarkOptions) -> Int {
    func OUT(_ s: String, _ wrap: Bool, _ escaping: CmarkEscaping) {renderer.out(renderer, s, wrap, escaping)}
    func LIT(_ s: String) {renderer.out(renderer, s, false, .literal)}
    func CR() {renderer.cr(renderer)}
    func BLANKLINE() {renderer.blankline(renderer)}
    
    let entering = (evType == .enter)
    let allowWrap = renderer.width > 0 && !options.contains(.nobreaks) &&
        !options.contains(.hardbreaks)
    
    // Don't adjust tight list status til we've started the list.
    // Otherwise we loose the blank line between a paragraph and
    // a following list.
    if !(node.type == .item && node.prev == nil && entering) {
        let tmp = node.getConainingBlock()
        renderer.inTightListItem =
            tmp != nil && // tmp might be NULL if there is no containing block
            ((tmp!.type == .item &&
                tmp!.parent?.getListTight() == true) ||
                (tmp != nil && tmp!.parent != nil && tmp!.parent!.type == .item &&
                    tmp!.parent!.parent?.getListTight() == true))
    }
    
    switch node.type {
    case .document:
        break
        
    case .blockQuote:
        if entering {
            LIT("> ")
            renderer.beginContent = true
            renderer.prefix.puts("> ")
        } else {
            renderer.prefix.truncate(renderer.prefix.size - 2)
            BLANKLINE()
        }
        
    case .list:
        if !entering && node.next != nil && (node.next!.type == .codeBlock ||
            node.next!.type == .list) {
            // this ensures that a following indented code block or list will be
            // inteprereted correctly.
            CR()
            LIT("<!-- end list -->")
            BLANKLINE()
        }
        
    case .item:
        var listmarker: String = ""
        let markerWidth: Int
        if node.parent?.getListType() == .bulletList {
            markerWidth = 4
        } else {
            var listNumber = node.parent!.getListStart()
            let listDelim = node.parent!.getListDelim()
            var tmp: CmarkNode? = node
            while let theNode = tmp?.prev {
                tmp = theNode
                listNumber += 1
            }
            // we ensure a width of at least 4 so
            // we get nice transition from single digits
            // to double
            listmarker = "\(listNumber)\(listDelim == .parenDelim ? ")" : ".")\(listNumber < 10 ? "  " : " ")"
            markerWidth = listmarker.utf8.count
        }
        if entering {
            if node.parent?.getListType() == .bulletList {
                LIT("  - ")
                renderer.beginContent = true
            } else {
                LIT(listmarker)
                renderer.beginContent = true
            }
            var i = markerWidth
            while i != 0 {
                i -= 1
                renderer.prefix.putc(" ")
            }
        } else {
            renderer.prefix.truncate(
                renderer.prefix.size - markerWidth)
            CR()
        }
        
    case .heading:
        if entering {
            for _ in 0..<node.getHeadingLevel() {
                LIT("#")
            }
            LIT(" ")
            renderer.beginContent = true
            renderer.noLinebreaks = true
        } else {
            renderer.noLinebreaks = false
            BLANKLINE()
        }
        
    case .codeBlock:
        let firstInListItem = node.prev == nil && node.parent != nil &&
            node.parent!.type == .item
        
        if !firstInListItem {
            BLANKLINE()
        }
        let info = node.getFenceInfo()!
        let code = node.asCode!.literal
        // use indented form if no info, and code doesn't
        // begin or end with a blank line, and code isn't
        // first thing in a list item
        if info.isEmpty && (code.len > 2 && !code.first!.isSpace &&
            !(code.last!.isSpace &&
                code[code.len - 2].isSpace)) &&
            !firstInListItem {
            LIT("    ")
            renderer.prefix.puts("    ")
            OUT(node.getLiteral()!, false, .literal)
            renderer.prefix.truncate(renderer.prefix.size - 4)
        } else {
            var numticks = longest_backtick_sequence(code) + 1
            if numticks < 3 {
                numticks = 3
            }
            for _ in 0..<numticks {
                LIT("`")
            }
            LIT(" ")
            OUT(info, false, .literal)
            CR()
            OUT(node.getLiteral()!, false, .literal)
            CR()
            for _ in 0..<numticks {
                LIT("`")
            }
        }
        BLANKLINE()
        
    case .htmlBlock:
        BLANKLINE()
        OUT(node.getLiteral()!, false, .literal)
        BLANKLINE()
        
    case .customBlock:
        BLANKLINE()
        OUT(entering ? node.getOnEnter()! : node.getOnExit()!,
            false, .literal)
        BLANKLINE()
        
    case .thematicBreak:
        BLANKLINE()
        LIT("-----")
        BLANKLINE()
        
    case .paragraph:
        if !entering {
            BLANKLINE()
        }
        
    case .text:
        OUT(node.getLiteral()!, allowWrap, .normal)
        
    case .linebreak:
        if !options.contains(.hardbreaks) {
            LIT("  ")
        }
        CR()
        
    case .softbreak:
        if options.contains(.hardbreaks) {
            LIT("  ")
            CR()
        } else if !renderer.noLinebreaks && renderer.width == 0 &&
            !options.contains(.hardbreaks) &&
            !options.contains(.nobreaks) {
            CR()
        } else {
            OUT(" ", allowWrap, .literal)
        }
        
    case .code:
        let code = node.asLiteral!
        let numticks = shortest_unused_backtick_sequence(code)
        for _ in 0..<numticks {
            LIT("`")
        }
        if code.isEmpty || code.first == "`" {
            LIT(" ")
        }
        OUT(node.getLiteral()!, allowWrap, .literal)
        if code.isEmpty || code.last == "`" {
            LIT(" ")
        }
        for _ in 0..<numticks {
            LIT("`")
        }
        
    case .htmlInline:
        OUT(node.getLiteral()!, false, .literal)
        
    case .customInline:
        OUT(entering ? node.getOnEnter()! : node.getOnExit()!,
            false, .literal)
        
    case .strong:
        if entering {
            LIT("**")
        } else {
            LIT("**")
        }
        
    case .emph:
        // If we have EMPH(EMPH(x)), we need to use *_x_*
        // because **x** is STRONG(x):
        let emphDelim: String
        if node.parent != nil && node.parent!.type == .emph &&
            node.next == nil && node.prev == nil {
            emphDelim = "_"
        } else {
            emphDelim = "*"
        }
        if entering {
            LIT(emphDelim)
        } else {
            LIT(emphDelim)
        }
        
    case .link:
        if node.isAutolink() {
            if entering {
                LIT("<")
                let url = node.getUrl()!
                if url.hasPrefix("mailto:") {
                    LIT(String(url[url.index(url.startIndex, offsetBy: 7)...]))
                } else {
                    LIT(url)
                }
                LIT(">")
                // return signal to skip contents of node...
                return 0
            }
        } else {
            if entering {
                LIT("[")
            } else {
                LIT("](")
                OUT(node.getUrl()!, false, .url)
                let title = node.getTitle()!
                if !title.isEmpty {
                    LIT(" \"")
                    OUT(title, false, .title)
                    LIT("\"")
                }
                LIT(")")
            }
        }
        
    case .image:
        if entering {
            LIT("![")
        } else {
            LIT("](")
            OUT(node.getUrl()!, false, .url)
            let title = node.getTitle()!
            if !title.isEmpty {
                OUT(" \"", allowWrap, .literal)
                OUT(title, false, .title)
                LIT("\"")
            }
            LIT(")")
        }
        
    default:
        assert(false)
    }
    
    return 1
}

extension CmarkNode {
    
    /** Render a 'node' tree as a commonmark document.
     * It is the caller's responsibility to free the returned buffer.
     */
    public func renderCommonmark(_ options: CmarkOptions, _ _width: Int) -> String {
        var width = _width
        if options.contains(.hardbreaks) {
            // disable breaking on width, since it has
            // a different meaning with OPT_HARDBREAKS
            width = 0
        }
        return render(options, width, outc, S_render_node)
    }
}
