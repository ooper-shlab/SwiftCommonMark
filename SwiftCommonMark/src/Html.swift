//
//  Html.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/16.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on html.c
 https://github.com/commonmark/cmark/blob/master/src/html.c
 
 Some comments moved from cmark.h
 https://github.com/commonmark/cmark/blob/master/src/cmark.h
 */

import Foundation

// Functions to convert cmark_nodes to HTML strings.
extension StringBuffer {
    ///lenth: valid length in UTF-8
    fileprivate func escapeHtml(_ source: StringChunk, _ length: Int) {
        let index = source.string.utf8.index(source.startIndex, offsetBy: length)
        escapeHtml0(source.string, source.startIndex, index, false)
    }
    
    fileprivate func escapeHtml(_ source: StringChunk) {
        escapeHtml0(source.string, source.startIndex, source.endIndex, false)
    }
    
    fileprivate func cr() {
        if let lastChar = self.last, lastChar != "\n" {
            putc("\n")
        }
    }
}

private struct RenderState {
    var html: StringBuffer
    var plain: CmarkNode?
}

extension CmarkNode {
    fileprivate func renderSourcepos(_ html: StringBuffer,
                                     _ options: CmarkOptions) {
        if options.contains(.sourcepos) {
            html.puts(" data-sourcepos=\"\(startLine):\(startColumn)-\(endLine):\(endColumn)\"")
        }
    }

    @discardableResult
    private func S_render_node(_ evType: CmarkEventType,
                               _ state: inout RenderState, _ options: CmarkOptions) -> Bool {
        let html = state.html
        
        let entering = (evType == .enter)
        
        if state.plain === self { // back at original node
            state.plain = nil
        }
        
        if state.plain != nil {
            switch type {
            case .text, .code, .htmlInline:
                html.escapeHtml(asLiteral!)
                
            case .linebreak, .softbreak:
                html.putc(" ")
                
            default:
                break
            }
            return true
        }
        
        switch type {
        case .document:
            break
            
        case .blockQuote:
            if entering {
                html.cr()
                html.puts("<blockquote")
                renderSourcepos(html, options)
                html.puts(">\n")
            } else {
                html.cr()
                html.puts("</blockquote>\n")
            }
            
        case .list:
            let listType = asList!.listType
            let start = asList!.start
            
            if entering {
                html.cr()
                if listType == .bulletList {
                    html.puts("<ul")
                    renderSourcepos(html, options)
                    html.puts(">\n")
                } else if start == 1 {
                    html.puts("<ol")
                    renderSourcepos(html, options)
                    html.puts(">\n")
                } else {
                    html.puts("<ol start=\"\(start)\"")
                    renderSourcepos(html, options)
                    html.puts(">\n")
                }
            } else {
                let endTag = listType == .bulletList ? "</ul>\n" : "</ol>\n"
                html.puts(
                    endTag)
            }
            
        case .item:
            if entering {
                html.cr()
                html.puts("<li")
                renderSourcepos(html, options)
                html.putc(">")
            } else {
                html.puts("</li>\n")
            }
            
        case .heading:
            if entering {
                html.cr()
                html.puts("<h\(asHeading!.level)")
                renderSourcepos(html, options)
                html.putc(">")
            } else {
                html.puts("</h\(asHeading!.level)>\n")
            }
            
        case .codeBlock:
            html.cr()
            
            if asCode?.info.isEmpty ?? true {
                html.puts("<pre")
                renderSourcepos(html, options)
                html.puts("><code>")
            } else {
                var firstTag = 0
                while firstTag < asCode?.info.len ?? 0 &&
                    !asCode!.info[firstTag].isSpace {
                        firstTag += 1
                }
                
                html.puts("<pre")
                renderSourcepos(html, options)
                html.puts("><code class=\"language-")
                html.escapeHtml(asCode!.info, firstTag)
                html.puts("\">")
            }
            
            html.escapeHtml(asCode!.literal)
            html.puts("</code></pre>\n")
            
        case .htmlBlock:
            html.cr()
            if options.contains(.safe) {
                html.puts("<!-- raw HTML omitted -->")
            } else {
                html.put(asLiteral!)
            }
            html.cr()
            
        case .customBlock:
            html.cr()
            if entering {
                html.put(asCustom!.onEnter)
            } else {
                html.put(asCustom!.onExit)
            }
            html.cr()
            
        case .thematicBreak:
            html.cr()
            html.puts("<hr")
            renderSourcepos(html, options)
            html.puts(" />\n")
            
        case .paragraph:
            let tight: Bool
            if let grandparent = parent?.parent, grandparent.type == .list {
                tight = grandparent.asList!.tight
            } else {
                tight = false
            }
            if !tight {
                if entering {
                    html.cr()
                    html.puts("<p")
                    renderSourcepos(html, options)
                    html.putc(">")
                } else {
                    html.puts("</p>\n")
                }
            }
            
        case .text:
            html.escapeHtml(asLiteral!)
            
        case .linebreak:
            html.puts("<br />\n")
            
        case .softbreak:
            if options.contains(.hardbreaks) {
                html.puts("<br />\n")
            } else if options.contains(.nobreaks) {
                html.putc(" ")
            } else {
                html.putc("\n")
            }
            
        case .code:
            html.puts("<code>")
            html.escapeHtml(asLiteral!)
            html.puts("</code>")
            
        case .htmlInline:
            if options.contains(.safe) {
                html.puts("<!-- raw HTML omitted -->")
            } else {
                html.put(asLiteral!)
            }
            
        case .customInline:
            if entering {
                html.put(asCustom!.onEnter)
            } else {
                html.put(asCustom!.onExit)
            }
            
        case .strong:
            if entering {
                html.puts("<strong>")
            } else {
                html.puts("</strong>")
            }
            
        case .emph:
            if entering {
                html.puts("<em>")
            } else {
                html.puts("</em>")
            }
            
        case .link:
            if entering {
                html.puts("<a href=\"")
                if !(options.contains(.safe) &&
                    asLink!.url.scanDangerousUrl(0) != 0) {
                    html.escapeHref(asLink!.url)
                }
                if asLink!.title.len != 0 {
                    html.puts("\" title=\"")
                    html.escapeHtml(asLink!.title)
                }
                html.puts("\">")
            } else {
                html.puts("</a>")
            }
            
        case .image:
            if entering {
                html.puts("<img src=\"")
                if !(options.contains(.safe) &&
                    asLink!.url.scanDangerousUrl(0) != 0) {
                    html.escapeHref(asLink!.url)
                }
                html.puts("\" alt=\"")
                state.plain = self
            } else {
                if asLink!.title.len != 0 {
                    html.puts("\" title=\"")
                    html.escapeHtml(asLink!.title)
                }
                
                html.puts("\" />")
            }
            
        default:
            assert(false)
        }
        
        // cmark_strbuf_putc(html, 'x');
        return true
    }
    
    /** Render a 'node' tree as an HTML fragment.  It is up to the user
     * to add an appropriate header and footer. It is the caller's
     * responsibility to free the returned buffer.
     */
    public func renderHtml(_ options: CmarkOptions) -> String {
        let html = StringBuffer()
        var state = RenderState(html: html, plain: nil)
        let iter = CmarkIter(self)
        
        while case let evType = iter.next(), evType != .done {
            let cur = iter.getNode()!
            cur.S_render_node(evType, &state, options)
        }
        let result = html.detach()
        
        iter.free()
        return result
    }
}
