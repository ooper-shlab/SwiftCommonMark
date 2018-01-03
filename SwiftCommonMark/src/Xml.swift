//
//  Xml.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/16.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on xml.c
 https://github.com/commonmark/cmark/blob/master/src/xml.c
 
 Some comments moved from cmark.h
 https://github.com/commonmark/cmark/blob/master/src/cmark.h
 */

import Foundation

// Functions to convert cmark_nodes to XML strings.

extension StringBuffer {
    fileprivate func escapeXml(_ chunk: StringChunk) {
        escapeHtml0(chunk.string, chunk.startIndex, chunk.endIndex, false)
    }
}

fileprivate class RenderState {
    let xml: StringBuffer
    var _indent: Int = 0
    
    init(xml: StringBuffer, indent: Int) {
        self.xml = xml
        self._indent = indent
        
    }
    
    fileprivate func indent() {
        for _ in 0..<_indent {
            xml.putc(" ")
        }
    }
    
    fileprivate func indentUp() {
        _indent += 2
    }
    fileprivate func indentDown() {
        _indent -= 2
    }
}
extension CmarkNode {
    @discardableResult
    fileprivate func S_render_node(_ evType: CmarkEventType,
                                   _ state: RenderState, _ options: CmarkOptions) -> Int {
        let xml = state.xml
        var literal = false
        let entering = (evType == .enter)
        
        if entering {
            state.indent()
            xml.putc("<")
            xml.puts(getTypeString())
            
            if options.contains(.sourcepos) && startLine != 0 {
                xml.puts(" sourcepos=\"\(startLine):\(startColumn)-\(endLine):\(endColumn)\"")
            }
            
            literal = false
            
            switch type {
            case .document:
                xml.puts(" xmlns=\"http://commonmark.org/xml/1.0\"")
            case .text, .code, .htmlBlock, .htmlInline:
                xml.puts(">")
                xml.escapeXml(asLiteral!)
                xml.puts("</")
                xml.puts(getTypeString())
                literal = true
            case .list:
                switch getListType() {
                case .orderedList:
                    xml.puts(" type=\"ordered\"")
                    xml.puts(" start=\"\(getListStart())\"")
                    let delim = getListDelim()
                    if delim == .parenDelim {
                        xml.puts(" delim=\"paren\"")
                    } else {
                        xml.puts(" delim=\"period\"")
                    }
                case .bulletList:
                    xml.puts(" type=\"bullet\"")
                default:
                    break
                }
                xml.puts(" tight=\"\(getListTight())\"")
            case .heading:
                xml.puts(" level=\"\(asHeading!.level)\"")
            case .codeBlock:
                if asCode!.info.len > 0 {
                    xml.puts(" info=\"")
                    xml.escapeXml(asCode!.info)
                    xml.putc("\"")
                }
                xml.puts(">")
                xml.escapeXml(asCode!.literal)
                xml.puts("</")
                xml.puts(getTypeString())
                literal = true
            case .customBlock, .customInline:
                xml.puts(" on_enter=\"")
                xml.escapeXml(asCustom!.onEnter)
                xml.putc("\"")
                xml.puts(" on_exit=\"")
                xml.escapeXml(asCustom!.onExit)
                xml.putc("\"")
            case .link, .image:
                xml.puts(" destination=\"")
                xml.escapeXml(asLink!.url)
                xml.putc("\"")
                xml.puts(" title=\"")
                xml.escapeXml(asLink!.title)
                xml.putc("\"")
            default:
                break
            }
            if firstChild != nil {
                state.indentUp()
            } else if !literal {
                xml.puts(" /")
            }
            xml.puts(">\n")
            
        } else if firstChild != nil {
            state.indentDown()
            state.indent()
            xml.puts("</")
            xml.puts(getTypeString())
            xml.puts(">\n")
        }
        
        return 1
    }
    
    /** Render a 'node' tree as XML.  It is the caller's responsibility
     * to free the returned buffer.
     */
    public func renderXml(_ options: CmarkOptions) -> String {
        let xml = StringBuffer()
        let state = RenderState(xml: xml, indent: 0)
        
        let iter = CmarkIter(self)
        
        state.xml.puts("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
        state.xml.puts("<!DOCTYPE document SYSTEM \"CommonMark.dtd\">\n")
        while case let evType = iter.next(), evType != .done {
            let cur = iter.getNode()
            cur?.S_render_node(evType, state, options)
        }
        let result = xml.detach()
        
        iter.free()
        return result
    }
}
