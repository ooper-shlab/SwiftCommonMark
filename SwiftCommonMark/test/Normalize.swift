//
//  Normalize.swift
//  SwiftCommonMarkTest
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/30.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on normalize.py
 https://github.com/commonmark/cmark/blob/master/test/normalize.py
 */

import Foundation

enum LastItem {
    case starttag
    case endtag
    case data
    case comment
    case decl
    case pi
    case ref
}

//# Normalization code, adapted from
//# https://github.com/karlcow/markdown-testsuite/
let whitespaceRe = try! NSRegularExpression(pattern: "\\s+")
class MyHTMLParserDelegate: NSObject, HTMLParserDelegate {
    var convertCharRefs: Bool = false
    var last: LastItem = .starttag
    var inPre: Bool = false
    var output: String = ""
    var lastTag: String = ""
    
    override init() {
        super.init()
    }
    
    func parser(_ parser: HTMLParser, foundCharacters string: String) {
        var data = string
        let afterTag = self.last == .endtag || self.last == .starttag
        let afterBlockTag = afterTag && isBlockTag(self.lastTag)
        if afterTag && self.lastTag == "br" {
            data = data.lstrip("\n")
        }
        if !self.inPre {
            data = whitespaceRe.sub(" ", data)
        }
        if afterBlockTag && !self.inPre {
            if self.last == .starttag {
                data = data.lstrip()
            } else if self.last == .endtag {
                data = data.strip()
            }
        }
        self.output += data
        self.last = .data
    }
    
    func parser(_ parser: HTMLParser, didEndElement elementName: String) {
        let tag = elementName.lowercased()
        if tag == "pre" {
            self.inPre = false
        } else if isBlockTag(tag) {
            self.output = self.output.rstrip()
        }
        if lastTag != tag || last != .starttag {
            output += "</" + tag + ">"
        }
        lastTag = tag
        last = .endtag
    }
    
    func parser(_ parser: HTMLParser, didStartElement elementName: String, attributes attributeDict: [String : String] = [:]) {
        let tag = elementName.lowercased()
        if tag == "pre" {
            self.inPre = true
        }
        if isBlockTag(tag) {
            self.output = self.output.rstrip()
        }
        self.output += "<" + tag
        //        # For now we don't strip out 'extra' attributes, because of
        //        # raw HTML test cases.
        //        # attrs = filter(lambda attr: attr[0] in significant_attrs, attrs)
        if !attributeDict.isEmpty {
            let attrs = attributeDict
                .map{(key: $0.key.lowercased(), value: $0.value)}
                .sorted{$0.key < $1.key}
            for (k,v) in attrs {
                self.output += " " + k
                if ["href","src"].contains(v) {
                    self.output += ("=\"" +
                        v.urllibUnquote().urllibQuote(safe: "/") + "\"")
                } else if !v.isEmpty {
                    self.output += ("=\"" + v.cgiEscape(quote: true) + "\"")
                }
            }
        }
        self.output += ">"
        self.lastTag = tag
        self.last = .starttag
    }
    
    func parser(_ parser: HTMLParser, foundComment comment: String) {
        self.output += "<!--" + comment + "-->"
        self.last = .comment
    }
    
    func parser(_ parser: HTMLParser, foundDoctypeDeclarationWithName name: String, publicID: String?, systemID: String?) {
        var publicIds = ""
        if let publicId = publicID, let systemId = systemID {
            publicIds = " PUBLIC \(publicId) \(systemId)"
        }
        output += "<!DOCTYPE \(name.lowercased())\(publicIds)>"
        last = .decl
    }

    func parser(_ parser: HTMLParser, foundProcessingInstructionWithTarget target: String, data: String?) {
        output += "<?" + target + (data ?? "") + "?>"
        last = .pi
    }
    
    func parser(_ parser: HTMLParser, foundNamedEntity name: String, character: String?) {
        if let ch = character {
            output(ch)
        } else {
            output += "&" + name + ";"
        }
        last = .ref
    }
    
    func parser(_ parser: HTMLParser, foundNumericEntity name: String, character: String?) {
        if let ch = character {
            output(ch)
        } else {
            output += "&#" + name + ";"
        }
        last = .ref
    }
    
    //    # Helpers.
    private func output(_ ch: String) {
        switch ch {
        case "<":
            self.output += "&lt;"
        case ">":
            self.output += "&gt;"
        case "&":
            self.output += "&amp;"
        case "\"":
            self.output += "&quot;"
        default:
            self.output += ch
        }
    }
    
    private func isBlockTag(_ tag: String) -> Bool {
        return ["article", "header", "aside", "hgroup", "blockquote",
                "hr", "iframe", "body", "li", "map", "button", "object", "canvas",
                "ol", "caption", "output", "col", "p", "colgroup", "pre", "dd",
                "progress", "div", "section", "dl", "table", "td", "dt",
                "tbody", "embed", "textarea", "fieldset", "tfoot", "figcaption",
                "th", "figure", "thead", "footer", "tr", "form", "ul",
                "h1", "h2", "h3", "h4", "h5", "h6", "video", "script", "style"].contains(tag)
    }
    
    func parserDidStartDocument(_ parser: HTMLParser) {
        //debugPrint(#function)
    }

    func parserDidEndDocument(_ parser: HTMLParser) {
        //debugPrint(#function)
    }
    
    func parser(_ parser: HTMLParser, foundCDATA CDATABlock: String) {
        output += "<![CDATA[" + CDATABlock + "]]>"
        last = .ref
    }
    
    func parser(_ parser: HTMLParser, parseErrorOccurred parseError: Error) {
        //# on error, return unnormalized HTML
        output = parser.string
    }
}

func normalize_html(_ html: String) -> String {
    //    r"""
    //    Return normalized form of HTML which ignores insignificant output
    //    differences:
    //
    //    Multiple inner whitespaces are collapsed to a single space (except
    //    in pre tags):
    //
    //        >>> normalize_html("<p>a  \t b</p>")
    //        '<p>a b</p>'
    //
    //        >>> normalize_html("<p>a  \t\nb</p>")
    //        '<p>a b</p>'
    //
    //    * Whitespace surrounding block-level tags is removed.
    //
    //        >>> normalize_html("<p>a  b</p>")
    //        '<p>a b</p>'
    //
    //        >>> normalize_html(" <p>a  b</p>")
    //        '<p>a b</p>'
    //
    //        >>> normalize_html("<p>a  b</p> ")
    //        '<p>a b</p>'
    //
    //        >>> normalize_html("\n\t<p>\n\t\ta  b\t\t</p>\n\t")
    //        '<p>a b</p>'
    //
    //        >>> normalize_html("<i>a  b</i> ")
    //        '<i>a b</i> '
    //
    //    * Self-closing tags are converted to open tags.
    //
    //        >>> normalize_html("<br />")
    //        '<br>'
    //
    //    * Attributes are sorted and lowercased.
    //
    //        >>> normalize_html('<a title="bar" HREF="foo">x</a>')
    //        '<a href="foo" title="bar">x</a>'
    //
    //    * References are converted to unicode, except that '<', '>', '&', and
    //      '"' are rendered using entities.
    //
    //        >>> normalize_html("&forall;&amp;&gt;&lt;&quot;")
    //        '\u2200&amp;&gt;&lt;&quot;'
    //
    //    """
    let delegate = MyHTMLParserDelegate()
    let parser = HTMLParser(string: html)
    parser.delegate = delegate
    parser.parse()
    return delegate.output
}


