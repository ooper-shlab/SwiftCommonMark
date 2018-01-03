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
    func scanHtmlBlockStart(_ n: Int) -> Int {
        return scan(_scan_html_block_start, at: n)
    }
    func scanHtmlBlockStart7(_ n: Int) -> Int {
        return scan(_scan_html_block_start_7, at: n)
    }
    func scanHtmlBlockEnd1(_ n: Int) -> Int {
        return scan(_scan_html_block_end_1, at: n)
    }
    func scanHtmlBlockEnd2(_ n: Int) -> Int {
        return scan(_scan_html_block_end_2, at: n)
    }
    func scanHtmlBlockEnd3(_ n: Int) -> Int {
        return scan(_scan_html_block_end_3, at: n)
    }
    func scanHtmlBlockEnd4(_ n: Int) -> Int {
        return scan(_scan_html_block_end_4, at: n)
    }
    func scanHtmlBlockEnd5(_ n: Int) -> Int {
        return scan(_scan_html_block_end_5, at: n)
    }
    func scanLinkTitle(_ index: String.Index) -> Int {
        return scan(_scan_link_title, at: index)
    }
    func scanSpacechars(_ index: String.Index, _ offset: Int = 0) -> Int {
        let start = string.utf8.index(index, offsetBy: offset)
        return scan(_scan_spacechars, at: start)
    }
    func scanAtxHeadingStart(_ n: Int) -> Int {
        return scan(_scan_atx_heading_start, at: n)
    }
    func scanSetextHeadingLine(_ n: Int) -> Int {
        return scan(_scan_setext_heading_line, at: n)
    }
    func scanThematicBreak(_ n: Int) -> Int {
        return scan(_scan_thematic_break, at: n)
    }
    func scanOpenCodeFence(_ n: Int) -> Int {
        return scan(_scan_open_code_fence, at: n)
    }
    func scanCloseCodeFence(_ n: Int) -> Int {
        return scan(_scan_close_code_fence, at: n)
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

let blocktagname = ["address","article","aside","base","basefont","blockquote","body","caption","center","col","colgroup","dd","details","dialog","dir","div","dl","dt","fieldset","figcaption","figure","footer","form","frame","frameset","h1","h2","h3","h4","h5","h6","head","header","hr","html","iframe","legend","li","link","main","menu","menuitem","meta","nav","noframes","ol","optgroup","option","p","param","section","source","title","summary","table","tbody","td","tfoot","th","thead","title","tr","track","ul"].i

let attributename = Re("[a-zA-Z_:][a-zA-Z0-9:._-]*")

let unquotedvalue = Re("[^\"'=<>`\\x00]+")
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

let htmltag = opentag | closetag | htmlcomment | processinginstruction |
    declaration | cdata

let in_parens_nosp   = "(" & (reg_char|escaped_char|"\\")* & ")"

let in_double_quotes = "\"" & (escaped_char|Re("[^\"\\x00]"))* & "\""
let in_single_quotes = "'" & (escaped_char|Re("[^'\\x00]"))* & "'"
let in_parens        = "(" & (escaped_char|Re("[^)\\x00]"))* & ")"

let scheme           = Re("[A-Za-z][A-Za-z0-9.+-]{1,31}")

// Try to match a scheme including colon.
private func _scan_scheme(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case scheme & ":":
        return p.size(from: start)
    default:
        return 0
    }
}

// Try to match URI autolink after first <, returning number of chars matched.
private func _scan_autolink_uri(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case scheme & Re(":[^\\x00-\\x20<>]*>"):
        return p.size(from: start)
    default:
        return 0
    }
}

// Try to match email autolink after first <, returning num of chars matched.
private func _scan_autolink_email(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case Re("[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+")
        & "@"
        & Re("[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?")
        & Re("([.][a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*")
        & ">":
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
func _scan_html_block_start(_ p: ReEnv) -> Int {
    switch p {
    case "<" & ["script", "pre", "style"].i & (spacechar | ">"):
        return 1
    case "<!--".i:
        return 2
    case "<?".i:
        return 3
    case "<!" & Re("[A-Z]"):
        return 4
    case "<![CDATA[".i:
        return 5
    case "<" & "/".opt & blocktagname & (spacechar | "/".opt & ">"):
        return 6
    default:
        return 0
    }
}

// Try to match an HTML block tag start line of type 7, returning
// 7 if successful, 0 if not.
private func _scan_html_block_start_7(_ p: ReEnv) -> Int {
    switch p {
    case "<" & (opentag | closetag) & Re("[\\t\\n\\f ]*[\\r\\n]"):
        return 7
    default:
        return 0
    }
}

// Try to match an HTML block end line of type 1
private func _scan_html_block_end_1(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case Re("[^\\n\\x00]*</") & ["script","pre","style"].i & ">":
        return p.size(from: start)
    default:
        return 0
    }
}

// Try to match an HTML block end line of type 2
private func _scan_html_block_end_2(_ p: ReEnv) -> Int {
    let start = p.current
    switch  p {
    case Re("[^\\n\\x00]*-->"):
        return p.size(from: start)
    default:
        return 0
    }
}

// Try to match an HTML block end line of type 3
private func _scan_html_block_end_3(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case Re("[^\\n\\x00]*") & "?>":
        return p.size(from: start)
    default:
        return 0
    }
}

// Try to match an HTML block end line of type 4
private func _scan_html_block_end_4(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case Re("[^\\n\\x00]*>"):
        return p.size(from: start)
    default:
        return 0
    }
}

// Try to match an HTML block end line of type 5
private func _scan_html_block_end_5(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case Re("[^\\n\\x00]*")&"]]>":
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
private func _scan_spacechars(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case Re("[ \\t\\v\\f\\r\\n]+"):
        return p.size(from: start)
    default:
        return 0
    }
}

// Match ATX heading start.
private func _scan_atx_heading_start(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case Re("#{1,6}(?:[ \\t]+|[\\r\\n])"):
        return p.size(from: start)
    default:
        return 0
    }
}

// Match setext heading line.  Return 1 for level-1 heading,
// 2 for level-2, 0 for no match.
private func _scan_setext_heading_line(_ p: ReEnv) -> Int {
    switch p {
    case Re("=+[ \t]*[\r\n]"):
        return 1
    case Re("-+[ \t]*[\r\n]"):
        return 2
    default:
        return 0
    }
}

// Scan a thematic break line: "...three or more hyphens, asterisks,
// or underscores on a line by themselves. If you wish, you may use
// spaces between the hyphens or asterisks."
private func _scan_thematic_break(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case Re("(\\*[ \\t]*){3,}[ \\t]*[\\r\\n]"):
        return p.size(from: start)
    case Re("(_[ \\t]*){3,}[ \\t]*[\\r\\n]"):
        return p.size(from: start)
    case Re("(\\-[ \\t]*){3,}[ \\t]*[\\r\\n]"):
        return p.size(from: start)
    default:
        return 0
    }
}

// Scan an opening code fence.
private func _scan_open_code_fence(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case Re("`{3,}")/Re("[^`\\r\\n\\x00]*[\\r\\n]"):
        return p.size(from: start)
    case Re("~{3,}")/Re("[^~\\r\\n\\x00]*[\\r\\n]"):
        return p.size(from: start)
    default:
        return 0
    }
}

// Scan a closing code fence with length at least len.
private func _scan_close_code_fence(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case Re("`{3,}")/Re("[ \t]*[\r\n]"):
        return p.size(from: start)
    case Re("~{3,}")/Re("[ \t]*[\r\n]"):
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
//     [&] ([#] ([Xx][A-Fa-f0-9]{1,8}|[0-9]{1,8}) |[A-Za-z][A-Za-z0-9]{1,31} ) [;]
//     { return (bufsize_t)(p - start); }
//     * { return 0; }
//     */
//}

// Returns positive value if a URL begins in a way that is potentially
// dangerous, with javascript:, vbscript:, file:, or data:, otherwise 0.
private func _scan_dangerous_url(_ p: ReEnv) -> Int {
    let start = p.current
    switch p {
    case "data:image/".i & ["png", "gif", "jpeg", "webp"].i:
        return 0
    case ["javascript:", "vbscript:", "file:", "data:"].i:
        return p.size(from: start)
    default:
        return 0
    }
}

