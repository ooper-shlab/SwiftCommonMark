//
//  Scanners.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/23.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on scanners.re and scanners.h (Not scanners.c, it's too big...)
 https://github.com/commonmark/cmark/blob/master/src/scanners.re
 https://github.com/commonmark/cmark/blob/master/src/scanners.h
 */

import Foundation

extension StringChunk {
    public func scanScheme(_ n: Int) -> Int {
        return scan(_scan_scheme, at: n)
    }
    func scanAutolinkUri(_ index: String.Index) -> Int {
        return scan(_scan_autolink_uri, at: index)
    }
    func scanAutolinkEmail(_ index: String.Index) -> Int {
        return scan(_scan_autolink_email, at: index)
    }
    func scanHtmlTag(_ index: String.Index) -> Int {
        return scan(_scan_html_tag, at: index)
    }
    func scanHtmlBlockStart(_ index: String.Index, _ offset: Int = 0) -> Int {
        let start = string.utf8.index(index, offsetBy: offset)
        return scan(_scan_html_block_start, at: start)
    }
    func scanHtmlBlockStart7(_ index: String.Index, _ offset: Int = 0) -> Int {
        let start = string.utf8.index(index, offsetBy: offset)
        return scan(_scan_html_block_start_7, at: start)
    }
    func scanHtmlBlockEnd1(_ index: String.Index, _ offset: Int = 0) -> Int {
        let start = string.utf8.index(index, offsetBy: offset)
        return scan(_scan_html_block_end_1, at: start)
    }
    func scanHtmlBlockEnd2(_ index: String.Index, _ offset: Int = 0) -> Int {
        let start = string.utf8.index(index, offsetBy: offset)
        return scan(_scan_html_block_end_2, at: start)
    }
    func scanHtmlBlockEnd3(_ index: String.Index, _ offset: Int = 0) -> Int {
        let start = string.utf8.index(index, offsetBy: offset)
        return scan(_scan_html_block_end_3, at: start)
    }
    func scanHtmlBlockEnd4(_ index: String.Index, _ offset: Int = 0) -> Int {
        let start = string.utf8.index(index, offsetBy: offset)
        return scan(_scan_html_block_end_4, at: start)
    }
    func scanHtmlBlockEnd5(_ index: String.Index, _ offset: Int = 0) -> Int {
        let start = string.utf8.index(index, offsetBy: offset)
        return scan(_scan_html_block_end_5, at: start)
    }
    func scanLinkTitle(_ index: String.Index) -> Int {
        return scan(_scan_link_title, at: index)
    }
    func scanSpacechars(_ index: String.Index, _ offset: Int = 0) -> Int {
        let start = string.utf8.index(index, offsetBy: offset)
        return scan(_scan_spacechars, at: start)
    }
    func scanAtxHeadingStart(_ index: String.Index, _ offset: Int = 0) -> Int {
        let start = string.utf8.index(index, offsetBy: offset)
        return scan(_scan_atx_heading_start, at: start)
    }
    func scanSetextHeadingLine(_ index: String.Index, _ offset: Int = 0) -> Int {
        let start = string.utf8.index(index, offsetBy: offset)
        return scan(_scan_setext_heading_line, at: start)
    }
    func scanThematicBreak(_ index: String.Index, _ offset: Int = 0) -> Int {
        let start = string.utf8.index(index, offsetBy: offset)
        return scan(_scan_thematic_break, at: start)
    }
    func scanOpenCodeFence(_ index: String.Index, _ offset: Int = 0) -> Int {
        let start = string.utf8.index(index, offsetBy: offset)
        return scan(_scan_open_code_fence, at: start)
    }
    func scanCloseCodeFence(_ index: String.Index, _ offset: Int = 0) -> Int {
        let start = string.utf8.index(index, offsetBy: offset)
        return scan(_scan_close_code_fence, at: start)
    }
    //### Not used
    //#define scan_entity(c, n) _scan_at(&_scan_entity, c, n)
    func scanDangerousUrl(_ n: Int) -> Int {
        return scan(_scan_dangerous_url, at: n)
    }
}

extension StringChunk {
    ///### offset: valid UTF-8 offset
    func scan(_ scanner: (ReEnv)->Int, at offset: Int) -> Int {
        
        let index = string.utf8.index(startIndex, offsetBy: offset)
        if index > endIndex {
            return 0
        } else {
            
            let env = ReEnv(string, index, endIndex)
            return scanner(env)
        }
        
    }
    func scan(_ scanner: (ReEnv)->Int, at index: String.Index) -> Int {
        
        let env = ReEnv(string, index, endIndex)
        return scanner(env)

    }
}

let wordchar = Re("[^\\x00-\\x20]")

let spacechar = Re("[ \\t\\v\\f\\r\\n]")

let reg_char = Re("[^\\\\()\\x00-\\x20]")

let escaped_char = Re("\\\\[!\"#$%&'()*+,./:;<=>?@\\[\\\\\\]^_`{|}~-]")

let tagname = Re("[A-Za-z][A-Za-z0-9-]*")

let blocktagname = ["address","article","aside","base","basefont","blockquote","body","caption","center","col","colgroup","dd","details","dialog","dir","div","dl","dt","fieldset","figcaption","figure","footer","form","frame","frameset","h1","h2","h3","h4","h5","h6","head","header","hr","html","iframe","legend","li","link","main","menu","menuitem","nav","noframes","ol","optgroup","option","p","param","section","source","title","summary","table","tbody","td","tfoot","th","thead","title","tr","track","ul"].i

let attributename = Re("[a-zA-Z_:][a-zA-Z0-9:._-]*")

let unquotedvalue = Re("[^ \\t\\r\\n\\x0C\\f\"'=<>`\\x00]+")
let singlequotedvalue = Re("'[^'\\x00]*'")
let doublequotedvalue = Re("\"[^\"\\x00]*\"")

let attributevalue = unquotedvalue | singlequotedvalue | doublequotedvalue

let attributevaluespec = spacechar* & "=" & spacechar* & attributevalue

let attribute = spacechar+ & attributename & attributevaluespec.opt

let opentag = tagname & attribute* & spacechar* & "/".opt & ">"
let closetag = "/" & tagname & spacechar* & ">"

let htmlcomment = "!---->" | ("!--" & ("-".opt & Re("[^\\x00>-]")) & ("-".opt & Re("[^\\x00-]"))* & "-->")

let processinginstruction = "?" & (Re("[^?>\\x00]+") | Re("[?][^>\\x00]") | ">")* & "?>"

let declaration = "!" & Re("[A-Z]+") & spacechar+ & Re("[^>\\x00]*") & ">"

let cdata = "![CDATA[" & (Re("[^\\]\\x00]+") | "]" & Re("[^\\]\\x00]") | "]]" & Re("[^>\\x00]"))* & "]]>"

let htmltag = (opentag | closetag | htmlcomment | processinginstruction |
    declaration | cdata).compile()

let in_parens_nosp   = "(" & (reg_char|escaped_char|"\\")* & ")"

let in_double_quotes = "\"" & (escaped_char|Re("[^\"\\x00]"))* & "\""
let in_single_quotes = "'" & (escaped_char|Re("[^'\\x00]"))* & "'"
let in_parens        = "(" & (escaped_char|Re("[^)\\x00]"))* & ")"

let scheme           = Re("[A-Za-z][A-Za-z0-9.+-]{1,31}")

// Try to match a scheme including colon.
private let schemeIncludingColon = (scheme & ":").compile()
private func _scan_scheme(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case schemeIncludingColon:
        return p.size(from: start)
    default:
        return 0
    }
}

// Try to match URI autolink after first <, returning number of chars matched.
private let autolink_uri = (scheme & Re(":[^\\x00-\\x20<>]*>")).compile()
private func _scan_autolink_uri(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case autolink_uri:
        return p.size(from: start)
    default:
        return 0
    }
}

// Try to match email autolink after first <, returning num of chars matched.
private let autolink_email = (
    Re("[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+")
    & "@"
    & Re("[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?")
    & Re("([.][a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*")
    & ">"
).compile()
private func _scan_autolink_email(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case autolink_email:
        return p.size(from: start)
    default:
        return 0
    }
}

// Try to match an HTML tag after first <, returning num of chars matched.
private func _scan_html_tag(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case htmltag:
        return p.size(from: start)
    default:
        return 0
    }
}

// Try to match an HTML block tag start line, returning
// an integer code for the type of block (1-6, matching the spec).
// #7 is handled by a separate function, below.
private let html_block_start1 = ("<" & ["script", "pre", "style"].i & (spacechar | ">")).compile()
private let html_block_start2 = ("<!--".i).compile()
private let html_block_start3 = ("<?".i).compile()
private let html_block_start4 = ("<!" & Re("[A-Z]")).compile()
private let html_block_start5 = ("<![CDATA[".i).compile()
private let html_block_start6 = ("<" & "/".opt & blocktagname & (spacechar | "/".opt & ">")).compile()
private func _scan_html_block_start(_ p: ReEnv) -> Int {
    switch p {
    case html_block_start1:
        return 1
    case html_block_start2:
        return 2
    case html_block_start3:
        return 3
    case html_block_start4:
        return 4
    case html_block_start5:
        return 5
    case html_block_start6:
        return 6
    default:
        return 0
    }
}

// Try to match an HTML block tag start line of type 7, returning
// 7 if successful, 0 if not.
private let html_block_start_7 = ("<" & (opentag | closetag) & Re("[\\t\\n\\f ]*[\\r\\n]")).compile()
private func _scan_html_block_start_7(_ p: ReEnv) -> Int {
    switch p {
    case html_block_start_7:
        return 7
    default:
        return 0
    }
}

// Try to match an HTML block end line of type 1
private let html_block_end_1 = (Re("[^\\n\\x00]*</") & ["script","pre","style"].i & ">").compile()
private func _scan_html_block_end_1(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case html_block_end_1:
        return p.size(from: start)
    default:
        return 0
    }
}

// Try to match an HTML block end line of type 2
private let html_block_end_2 = Re("[^\\n\\x00]*-->").compile()
private func _scan_html_block_end_2(_ p: ReEnv) -> Int {
    let start = p.current
    switch  p {
    case html_block_end_2:
        return p.size(from: start)
    default:
        return 0
    }
}

// Try to match an HTML block end line of type 3
private let html_block_end_3 = (Re("[^\\n\\x00]*") & "?>").compile()
private func _scan_html_block_end_3(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case html_block_end_3:
        return p.size(from: start)
    default:
        return 0
    }
}

// Try to match an HTML block end line of type 4
private let html_block_end_4 = Re("[^\\n\\x00]*>").compile()
private func _scan_html_block_end_4(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case html_block_end_4:
        return p.size(from: start)
    default:
        return 0
    }
}

// Try to match an HTML block end line of type 5
private let html_block_end_5 = (Re("[^\\n\\x00]*")&"]]>").compile()
private func _scan_html_block_end_5(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case html_block_end_5:
        return p.size(from: start)
    default:
        return 0
    }
}

// Try to match a link title (in single quotes, in double quotes, or
// in parentheses), returning number of chars matched.  Allow one
// level of internal nesting (quotes within quotes).
private let linkTitle1 = ("\"" & (escaped_char|Re("[^\"\\x00]"))* & "\"").compile()
private let linkTitle2 = ("'" & (escaped_char|Re("[^'\\x00]"))* & "'").compile()
private let linkTitle3 = ("(" & (escaped_char|Re("[^)\\x00]"))* & ")").compile()
private func _scan_link_title(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case linkTitle1:
        return p.size(from: start)
    case linkTitle2:
        return p.size(from: start)
    case linkTitle3:
        return p.size(from: start)
    default:
        return 0
    }
}

// Match space characters, including newlines.
private let spacechars = Re("[ \\t\\v\\f\\r\\n]+").compile()
private func _scan_spacechars(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case spacechars:
        return p.size(from: start)
    default:
        return 0
    }
}

// Match ATX heading start.
private let atx_heading_start = Re("#{1,6}(?:[ \\t]+|[\\r\\n])").compile()
private func _scan_atx_heading_start(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case atx_heading_start:
        return p.size(from: start)
    default:
        return 0
    }
}

// Match setext heading line.  Return 1 for level-1 heading,
// 2 for level-2, 0 for no match.
private let setext_heading_line1 = Re("=+[ \t]*[\r\n]").compile()
private let setext_heading_line2 = Re("-+[ \t]*[\r\n]").compile()
private func _scan_setext_heading_line(_ p: ReEnv) -> Int {
    switch p {
    case setext_heading_line1:
        return 1
    case setext_heading_line2:
        return 2
    default:
        return 0
    }
}

// Scan a thematic break line: "...three or more hyphens, asterisks,
// or underscores on a line by themselves. If you wish, you may use
// spaces between the hyphens or asterisks."
private let thematic_break1 = Re("(\\*[ \\t]*){3,}[ \\t]*[\\r\\n]").compile()
private let thematic_break2 = Re("(_[ \\t]*){3,}[ \\t]*[\\r\\n]").compile()
private let thematic_break3 = Re("(\\-[ \\t]*){3,}[ \\t]*[\\r\\n]").compile()
private func _scan_thematic_break(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case thematic_break1:
        return p.size(from: start)
    case thematic_break2:
        return p.size(from: start)
    case thematic_break3:
        return p.size(from: start)
    default:
        return 0
    }
}

// Scan an opening code fence.
private let open_code_fence1 = (Re("`{3,}")/Re("[^`\\r\\n\\x00]*[\\r\\n]")).compile()
private let open_code_fence2 = (Re("~{3,}")/Re("[^~\\r\\n\\x00]*[\\r\\n]")).compile()
private func _scan_open_code_fence(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case open_code_fence1:
        return p.size(from: start)
    case open_code_fence2:
        return p.size(from: start)
    default:
        return 0
    }
}

// Scan a closing code fence with length at least len.
private let close_code_fence1 = (Re("`{3,}")/Re("[ \t]*[\r\n]")).compile()
private let close_code_fence2 = (Re("~{3,}")/Re("[ \t]*[\r\n]")).compile()
private func _scan_close_code_fence(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case close_code_fence1:
        return p.size(from: start)
    case close_code_fence2:
        return p.size(from: start)
    default:
        return 0
    }
}

//### Not used
//// Scans an entity.
//// Returns number of chars matched.
//bufsize_t _scan_entity(const unsigned char *p)
//{
//    const unsigned char *marker = NULL;
//    const unsigned char *start = p;
//    /*!re2c
//     [&] ([#] ([Xx][A-Fa-f0-9]{1,6}|[0-9]{1,7}) |[A-Za-z][A-Za-z0-9]{1,31} ) [;]
//     { return (bufsize_t)(p - start); }
//     * { return 0; }
//     */
//}

// Returns positive value if a URL begins in a way that is potentially
// dangerous, with javascript:, vbscript:, file:, or data:, otherwise 0.
private let dangerous_url1 = ("data:image/".i & ["png", "gif", "jpeg", "webp"].i).compile()
private let dangerous_url2 = (["javascript:", "vbscript:", "file:", "data:"].i).compile()
private func _scan_dangerous_url(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case dangerous_url1:
        return 0
    case dangerous_url2:
        return p.size(from: start)
    default:
        return 0
    }
}

