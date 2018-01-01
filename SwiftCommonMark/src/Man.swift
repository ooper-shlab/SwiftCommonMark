//
//  Man.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/16.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on man.c
 https://github.com/commonmark/cmark/blob/master/src/man.c
 
 Some comments moved from cmark.h
 https://github.com/commonmark/cmark/blob/master/src/cmark.h
 */

import Foundation

// Functions to convert cmark_nodes to groff man strings.
private func S_outc(_ renderer: CmarkRenderer, _ escape: CmarkEscaping, _ c: Int32,
                    _ nextc: UInt8) {
    
    if escape == .literal {
        renderer.renderCodePoint(c)
        return
    }
    
    switch c {
    case 46:
        if renderer.beginLine {
            renderer.renderAscii("\\&.")
        } else {
            renderer.renderCodePoint(c)
        }
    case 39:
        if renderer.beginLine {
            renderer.renderAscii("\\&'")
        } else {
            renderer.renderCodePoint(c)
        }
    case 45:
        renderer.renderAscii("\\-")
    case 92:
        renderer.renderAscii("\\e")
    case 8216: // left single quote
        renderer.renderAscii("\\[oq]")
    case 8217: // right single quote
        renderer.renderAscii("\\[cq]")
    case 8220: // left double quote
        renderer.renderAscii("\\[lq]")
    case 8221: // right double quote
        renderer.renderAscii("\\[rq]")
    case 8212: // em dash
        renderer.renderAscii("\\[em]")
    case 8211: // en dash
        renderer.renderAscii("\\[en]")
    default:
        renderer.renderCodePoint(c)
    }
}

private func S_render_node(_ renderer: CmarkRenderer, _ node: CmarkNode,
                           _ evType: CmarkEventType, _ options: CmarkOptions) -> Int{
    func CR() {
        renderer.cr(renderer)
    }
    func LIT(_ s: String) {
        renderer.out(renderer, s, false, .literal)
    }
    func OUT(_ s: String, _ wrap: Bool, _ escaping: CmarkEscaping) {
        renderer.out(renderer, s, wrap, escaping)
    }
    
    let entering = evType == .enter
    let allowWrap = renderer.width > 0 && !options.contains(.nobreaks)
    
    switch node.type {
    case .document:
        break
        
    case .blockQuote:
        if entering {
            CR()
            LIT(".RS")
            CR()
        } else {
            CR()
            LIT(".RE")
            CR()
        }
        
    case .list:
        break
        
    case .item:
        if entering {
            CR()
            LIT(".IP ")
            if node.parent?.getListType() == .bulletList {
                LIT("\\[bu] 2")
            } else {
                var listNumber = node.parent?.getListStart() ?? 0
                var tmp = node
                while let prev = tmp.prev {
                    tmp = prev
                    listNumber += 1
                }
                LIT("\"\(listNumber).\" 4")
            }
            CR()
        } else {
            CR()
        }
        
    case .heading:
        if entering {
            CR()
            let lit = node.getHeadingLevel() == 1 ? ".SH" : ".SS"
            LIT(lit)
            CR()
        } else {
            CR()
        }
        
    case .codeBlock:
        CR()
        LIT(".IP\n.nf\n\\f[C]\n")
        OUT(node.getLiteral()!, false, .normal)
        CR()
        LIT("\\f[]\n.fi")
        CR()
        
    case .htmlBlock:
        break
        
    case .customBlock:
        CR()
        OUT(entering ? node.getOnEnter()! : node.getOnExit()!,
            false, .literal)
        CR()
        
    case .thematicBreak:
        CR()
        LIT(".PP\n  *  *  *  *  *")
        CR()
        
    case .paragraph:
        if entering {
            // no blank line if first paragraph in list:
            if let parent = node.parent, parent.type == .item,
                node.prev == nil {
                // no blank line or .PP
            } else {
                CR()
                LIT(".PP")
                CR()
            }
        } else {
            CR()
        }
        
    case .text:
        OUT(node.getLiteral()!, allowWrap, .normal)
        
    case .linebreak:
        LIT(".PD 0\n.P\n.PD")
        CR()
        
    case .softbreak:
        if options.contains(.hardbreaks) {
            LIT(".PD 0\n.P\n.PD")
            CR()
        } else if renderer.width == 0 && !options.contains(.nobreaks) {
            CR()
        } else {
            OUT(" ", allowWrap, .literal)
        }
        
    case .code:
        LIT("\\f[C]")
        OUT(node.getLiteral()!, allowWrap, .normal)
        LIT("\\f[]")
        
    case .htmlInline:
        break
        
    case .customInline:
        OUT(entering ? node.getOnEnter()! : node.getOnExit()!,
            false, .literal)
        
    case .strong:
        if entering {
            LIT("\\f[B]")
        } else {
            LIT("\\f[]")
        }
        
    case .emph:
        if entering {
            LIT("\\f[I]")
        } else {
            LIT("\\f[]")
        }
        
    case .link:
        if !entering {
            LIT(" (")
            OUT(node.getUrl()!, allowWrap, .url)
            LIT(")")
        }
        
    case .image:
        if entering {
            LIT("[IMAGE: ")
        } else {
            LIT("]")
        }
        
    default:
        assert(false)
    }
    
    return 1
}

public extension CmarkNode {
    
    /** Render a 'node' tree as a groff man page, without the header.
     * It is the caller's responsibility to free the returned buffer.
     */
    public func renderMan(_ options: CmarkOptions, _ width: Int) -> String {
        return self.render(options, width, S_outc, S_render_node)
    }
}
