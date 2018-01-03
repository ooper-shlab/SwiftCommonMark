//
//  Latex.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/17.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on latex.c
 https://github.com/commonmark/cmark/blob/master/src/latex.c
 
 Some comments moved from cmark.h
 https://github.com/commonmark/cmark/blob/master/src/cmark.h
 */

import Foundation

private func outc(_ renderer: CmarkRenderer, _ escape: CmarkEscaping,
                  _ c: Int32, _ nextc: UInt8) {
    if escape == .literal {
        renderer.renderCodePoint(c)
    }
    
    switch c {
    case 123, 125, 35, 37, 38: // '{','}', '#', '%', '&'
        renderer.renderAscii("\\")
        renderer.renderCodePoint(c)
    case 36, 95: // '$', '_'
        if escape == .normal {
            renderer.renderAscii("\\")
        }
        renderer.renderCodePoint(c)
    case 45:             // '-'
        if nextc == 45 {
            renderer.renderAscii("-{}")
        } else {
            renderer.renderAscii("-")
        }
    case 126: // '~'
        if escape == .normal {
            renderer.renderAscii("\\textasciitilde{}")
        } else {
            renderer.renderCodePoint(c)
        }
    case 94: // '^'
        renderer.renderAscii("\\^{}")
    case 92: // '\\'
        if escape == .url {
            // / acts as path sep even on windows:
            renderer.renderAscii("/")
        } else {
            renderer.renderAscii("\\textbackslash{}")
        }
    case 124: // '|'
        renderer.renderAscii("\\textbar{}")
    case 60: // '<'
        renderer.renderAscii("\\textless{}")
    case 62: // '>'
        renderer.renderAscii("\\textgreater{}")
    case 91, 93: // '[', ']'
        renderer.renderAscii("{")
        renderer.renderCodePoint(c)
        renderer.renderAscii("}")
    case 34: // '"'
        renderer.renderAscii("\\textquotedbl{}")
    // requires \usepackage[T1]{fontenc}
    case 39: // '\''
        renderer.renderAscii("\\textquotesingle{}")
    // requires \usepackage{textcomp}
    case 160: // nbsp
        renderer.renderAscii("~")
    case 8230: // hellip
        renderer.renderAscii("\\ldots{}")
    case 8216: // lsquo
        if escape == .normal {
            renderer.renderAscii("`")
        } else {
            renderer.renderCodePoint(c)
        }
    case 8217: // rsquo
        if escape == .normal {
            renderer.renderAscii("'")
        } else {
            renderer.renderCodePoint(c)
        }
    case 8220: // ldquo
        if escape == .normal {
            renderer.renderAscii("``")
        } else {
            renderer.renderCodePoint(c)
        }
    case 8221: // rdqu
        if escape == .normal {
            renderer.renderAscii("''")
        } else {
            renderer.renderCodePoint(c)
        }
    case 8212: // emdash
        if escape == .normal {
            renderer.renderAscii("---")
        } else {
            renderer.renderCodePoint(c)
        }
    case 8211: // endash
        if escape == .normal {
            renderer.renderAscii("--")
        } else {
            renderer.renderCodePoint(c)
        }
    default:
        renderer.renderCodePoint(c)
    }
}

private enum LinkType {
    case noLink
    case urlAutolink
    case emailAutolink
    case normalLink
    case internalLink
}

extension CmarkNode {
    fileprivate func getLinkType() -> LinkType {
        var isemail = false
        
        guard type == .link else {
            return .noLink
        }
        
        let url = getUrl()!
        let urlChunk = StringChunk(literal: url)

        if url.first == "#" {
            return .internalLink
        }
        
        if url.isEmpty || urlChunk.scanScheme(0) == 0 {
            return .noLink
        }
        
        let title = getTitle()!
        // if it has a title, we can't treat it as an autolink:
        if title.isEmpty {
            
            guard let linkText = firstChild else {return .noLink}
            linkText.consolidateTextNodes()
            
            var realurl: String = url
            if url.hasPrefix("mailto:") {
                realurl = String(realurl[realurl.index(realurl.startIndex, offsetBy: 7)...])
                isemail = true
            }
            if realurl == linkText.getLiteral() {
                if isemail {
                    return .emailAutolink
                } else {
                    return .urlAutolink
                }
            }
        }
        
        return .normalLink
    }
    
    fileprivate func getEnumlevel() -> Int {
        var enumlevel = 0
        var tmp: CmarkNode? = self
        while let theNode = tmp {
            if theNode.type == .list &&
                getListType() == .orderedList {
                enumlevel += 1
            }
            tmp = theNode.parent
        }
        return enumlevel
    }
}

private func S_render_node(_ renderer: CmarkRenderer, _ node: CmarkNode,
                           _ evType: CmarkEventType, _ options: CmarkOptions) -> Int {
    func OUT(_ s: String, _ wrap: Bool, _ escaping: CmarkEscaping) {renderer.out(renderer, s, wrap, escaping)}
    func LIT(_ s: String) {renderer.out(renderer, s, false, .literal)}
    func CR() {renderer.cr(renderer)}
    func BLANKLINE() {renderer.blankline(renderer)}
    
    let entering = evType == .enter
    let allowWrap = renderer.width > 0 && !options.contains(.nobreaks)
    
    switch node.type {
    case .document:
        break
        
    case .blockQuote:
        if entering {
            LIT("\\begin{quote}")
            CR()
        } else {
            LIT("\\end{quote}")
            BLANKLINE()
        }
        
    case .list:
        let listType = node.getListType()
        if entering {
            LIT("\\begin{")
            LIT(listType == .orderedList ? "enumerate" : "itemize")
            LIT("}")
            CR()
            let listNumber = node.getListStart()
            if listNumber > 1 {
                let enumlevel = node.getEnumlevel()
                // latex normally supports only five levels
                if enumlevel >= 1 && enumlevel <= 5 {
                    LIT("\\setcounter{enum")
                    switch enumlevel {
                    case 1: LIT("i")
                    case 2: LIT("ii")
                    case 3: LIT("iii")
                    case 4: LIT("iv")
                    case 5: LIT("v")
                    default: LIT("i")
                    }
                    LIT("}{")
                    OUT(String(listNumber), false, .normal)
                    LIT("}")
                }
                CR()
            }
        } else {
            LIT("\\end{")
            LIT(listType == .orderedList ? "enumerate" : "itemize")
            LIT("}")
            BLANKLINE()
        }
        
    case .item:
        if entering {
            LIT("\\item ")
        } else {
            CR()
        }
        
    case .heading:
        if entering {
            switch node.getHeadingLevel() {
            case 1:
                LIT("\\section")
            case 2:
                LIT("\\subsection")
            case 3:
                LIT("\\subsubsection")
            case 4:
                LIT("\\paragraph")
            case 5:
                LIT("\\subparagraph")
            default:
                break
            }
            LIT("{")
        } else {
            LIT("}")
            BLANKLINE()
        }
        
    case .codeBlock:
        CR()
        LIT("\\begin{verbatim}")
        CR()
        OUT(node.getLiteral()!, false, .literal)
        CR()
        LIT("\\end{verbatim}")
        BLANKLINE()
        
    case .htmlBlock:
        break
        
    case .customBlock:
        CR()
        OUT(entering ? node.getOnEnter()! : node.getOnExit()!, false, .literal)
        CR()
        
    case .thematicBreak:
        BLANKLINE()
        LIT("\\begin{center}\\rule{0.5\\linewidth}{\\linethickness}\\end{center}")
        BLANKLINE()
        
    case .paragraph:
        if !entering {
            BLANKLINE()
        }
        
    case .text:
        OUT(node.getLiteral()!, allowWrap, .normal)
        
    case .linebreak:
        LIT("\\\\")
        CR()
        
    case .softbreak:
        if options.contains(.hardbreaks) {
            LIT("\\\\")
            CR()
        } else if renderer.width == 0 && !options.contains(.nobreaks) {
            CR()
        } else {
            OUT(" ", allowWrap, .normal)
        }
        
    case .code:
        LIT("\\texttt{")
        OUT(node.getLiteral()!, false, .normal)
        LIT("}")
        
    case .htmlInline:
        break
        
    case .customInline:
        OUT(entering ? node.getOnEnter()! : node.getOnExit()!,
            false, .literal)
        
    case .strong:
        if entering {
            LIT("\\textbf{")
        } else {
            LIT("}")
        }
        
    case .emph:
        if entering {
            LIT("\\emph{")
        } else {
            LIT("}")
        }
        
    case .link:
        if entering {
            let url = node.getUrl()!
            // requires \usepackage{hyperref}
            switch node.getLinkType() {
            case .urlAutolink:
                LIT("\\url{")
                OUT(url, false, .url)
                LIT("}")
                return 0 // Don't process further nodes to avoid double-rendering artefacts
            case .emailAutolink:
                LIT("\\href{")
                OUT(url, false, .url)
                LIT("}\\nolinkurl{")
            case .normalLink:
                LIT("\\href{")
                OUT(url, false, .url)
                LIT("}{")
            case .internalLink:
                LIT("\\protect\\hyperlink{")
                OUT(String(url.dropFirst()), false, .url)
                LIT("}{")
            case .noLink:
                LIT("{") // error?
            }
        } else {
            LIT("}")
        }
        
    case .image:
        if entering {
            LIT("\\protect\\includegraphics{")
            // requires \include{graphicx}
            OUT(node.getUrl()!, false, .url)
            LIT("}")
            return 0
        }
        
    default:
        assert(false)
    }
    
    return 1
}

extension CmarkNode {
    
    /** Render a 'node' tree as a LaTeX document.
     * It is the caller's responsibility to free the returned buffer.
     */
    func renderLatex(_ options: CmarkOptions, _ width: Int) -> String {
        return render(options, width, outc, S_render_node)
    }
}
