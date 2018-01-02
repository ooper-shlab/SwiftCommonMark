//
//  SwiftCommonMarkTest.swift
//  SwiftCommonMarkTest
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/17.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on api_test/main.c
 https://github.com/commonmark/cmark/blob/master/api_test/main.c
 */

import XCTest

class SwiftCommonMarkTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testVersion() {
        XCTAssertEqual(cmark_version(), CMARK_VERSION, "cmark_version")
        XCTAssertEqual(cmark_version_string(), CMARK_VERSION_STRING,
                       "cmark_version_string")
    }
    
    func testConstructor() {
        for type in nodeTypes {
            let node = CmarkNode(type: type)
            XCTAssertEqual(node.type, type, "get_type \(type)")
            
            switch node.type {
            case .heading:
                XCTAssertEqual(node.getHeadingLevel(), 1,
                               "default heading level is 1")
                var heading = node.asHeading!
                heading.level = 1
                node.asType = .heading(heading)
                
            case .list:
                XCTAssertEqual(node.getListType(), CmarkListType.bulletList,
                               "default is list type is bullet")
                XCTAssertEqual(node.getListDelim(), CmarkDelimType.noDelim,
                               "default is list delim is NO_DELIM")
                XCTAssertEqual(node.getListStart(), 0,
                               "default is list start is 0")
                XCTAssertEqual(node.getListTight(), false,
                               "default is list is loose")
                
            default:
                break
            }
            
            node.free()
        }
    }
    
    func testAccessors() {
        let markdown = """
            ## Header
            
            * Item 1
            * Item 2
            
            2. Item 1
            
            3. Item 2
            
            ``` lang
            fenced
            ```
                code
            
            <div>html</div>
            
            [link](url 'title')
            
            """
        
        let doc = cmark_parse_document(markdown, .default)
        
        // Getters
        
        let heading = doc.firstChild
        XCTAssertEqual(heading?.getHeadingLevel(), 2, "get_heading_level")
        
        let bullet_list = heading?.next
        XCTAssertEqual(bullet_list?.type, CmarkNodeType.list)
        XCTAssertEqual(bullet_list?.getListType(), CmarkListType.bulletList,
                       "get_list_type bullet")
        XCTAssertEqual(bullet_list?.getListTight(), true,
                       "get_list_tight tight")
        
        let ordered_list = bullet_list?.next
        XCTAssertEqual(ordered_list?.type, CmarkNodeType.list)
        XCTAssertEqual(ordered_list?.getListType(), .orderedList,
                       "get_list_type ordered")
        XCTAssertEqual(ordered_list?.getListDelim(), .periodDelim,
                       "get_list_delim ordered")
        XCTAssertEqual(ordered_list?.getListStart(), 2, "get_list_start")
        XCTAssertEqual(ordered_list?.getListTight(), false,
                       "get_list_tight loose")
        
        let fenced = ordered_list?.next
        XCTAssertEqual(fenced?.type, CmarkNodeType.codeBlock)
        XCTAssertEqual(fenced?.getLiteral(), "fenced\n",
                       "get_literal fenced code")
        XCTAssertEqual(fenced?.getFenceInfo(), "lang", "get_fence_info")
        
        let code = fenced?.next
        XCTAssertEqual(code?.type, CmarkNodeType.codeBlock)
        XCTAssertEqual(code?.getLiteral(), "code\n",
                       "get_literal indented code")
        
        let html = code?.next
        XCTAssertEqual(html?.type, CmarkNodeType.htmlBlock)
        XCTAssertEqual(html?.getLiteral(), "<div>html</div>\n",
                       "get_literal html")
        
        let paragraph = html?.next
        XCTAssertEqual(paragraph?.type, CmarkNodeType.paragraph)
        XCTAssertEqual(paragraph?.startLine, 17, "get_start_line")
        XCTAssertEqual(paragraph?.startColumn, 1, "get_start_column")
        XCTAssertEqual(paragraph?.endLine, 17, "get_end_line")
        
        let link = paragraph?.firstChild
        XCTAssertEqual(link?.type, CmarkNodeType.link)
        XCTAssertEqual(link?.getUrl(), "url", "get_url")
        XCTAssertEqual(link?.getTitle(), "title", "get_title")
        
        let string = link?.firstChild
        XCTAssertEqual(string?.type, CmarkNodeType.text)
        XCTAssertEqual(string?.getLiteral(), "link", "get_literal string")
        
        // Setters
        
        XCTAssert(heading!.setHeadingLevel(3), "set_heading_level")
        XCTAssertEqual(heading!.getHeadingLevel(), 3)
        
        XCTAssert(bullet_list!.setListType(.orderedList),
                  "set_list_type ordered")
        XCTAssertEqual(bullet_list!.getListType(), .orderedList)
        XCTAssert(bullet_list!.setListDelim(.parenDelim),
                  "set_list_delim paren")
        XCTAssertEqual(bullet_list!.getListDelim(), .parenDelim)
        XCTAssert(bullet_list!.setListStart(3), "set_list_start")
        XCTAssertEqual(bullet_list!.getListStart(), 3)
        XCTAssert(bullet_list!.setListTight(false), "set_list_tight loose")
        XCTAssertEqual(bullet_list!.getListTight(), false)
        
        XCTAssert(ordered_list!.setListType(.bulletList),
                  "set_list_type bullet")
        XCTAssertEqual(ordered_list!.getListType(), .bulletList)
        XCTAssert(ordered_list!.setListTight(true),
                  "set_list_tight tight")
        XCTAssertEqual(ordered_list!.getListTight(), true)
        
        XCTAssert(code!.setLiteral("CODE\n"),
                  "set_literal indented code")
        XCTAssertEqual(code!.getLiteral(), "CODE\n")
        
        XCTAssert(fenced!.setLiteral("FENCED\n"),
                  "set_literal fenced code")
        XCTAssertEqual(fenced!.getLiteral(), "FENCED\n")
        XCTAssert(fenced!.setFenceInfo("LANG"), "set_fence_info")
        XCTAssertEqual(fenced!.getFenceInfo(), "LANG")
        
        XCTAssert(html!.setLiteral("<div>HTML</div>\n"),
                  "set_literal html")
        XCTAssertEqual(html!.getLiteral(), "<div>HTML</div>\n")
        
        XCTAssert(link!.setUrl("URL"), "set_url")
        XCTAssertEqual(link!.getUrl(), "URL")
        XCTAssert(link!.setTitle("TITLE"), "set_title")
        XCTAssertEqual(link!.getTitle(), "TITLE")
        
        XCTAssert(string!.setLiteral("prefix-LINK"),
                  "set_literal string")
        XCTAssertEqual(string!.getLiteral(), "prefix-LINK")
        
        // Set literal to suffix of itself (issue #139).
        let literal = string!.getLiteral()!
        let start = literal.index(literal.startIndex, offsetBy: "prefix-".count)
        XCTAssert(string!.setLiteral(String(literal[start...])),
                  "set_literal suffix")
        XCTAssertEqual(string!.getLiteral(), "LINK")
        
        let renderedHtml = doc.renderHtml(.default)
        let expected_html = """
            <h3>Header</h3>
            <ol start=\"3\">
            <li>
            <p>Item 1</p>
            </li>
            <li>
            <p>Item 2</p>
            </li>
            </ol>
            <ul>
            <li>Item 1</li>
            <li>Item 2</li>
            </ul>
            <pre><code class=\"language-LANG\">FENCED
            </code></pre>
            <pre><code>CODE
            </code></pre>
            <div>HTML</div>
            <p><a href=\"URL\" title=\"TITLE\">LINK</a></p>

            """
        XCTAssertEqual(renderedHtml, expected_html, "setters work")
        
        // Getter errors
        
        XCTAssertEqual(bullet_list?.getHeadingLevel(), 0,
                       "get_heading_level error")
        XCTAssertEqual(heading?.getListType(), .noList,
                       "get_list_type error")
        XCTAssertEqual(code?.getListStart(), 0, "get_list_start error")
        XCTAssertEqual(fenced?.getListTight(), false, "get_list_start error")
        XCTAssertEqual(ordered_list?.getLiteral(), nil, "get_literal error")
        XCTAssertEqual(paragraph?.getFenceInfo(), nil,
                       "get_fence_info error")
        XCTAssertEqual(html?.getUrl(), nil, "get_url error")
        XCTAssertEqual(heading?.getTitle(), nil, "get_title error")
        
        // Setter errors
        
        XCTAssert(!bullet_list!.setHeadingLevel(3),
                  "set_heading_level error")
        XCTAssert(!heading!.setListType(.orderedList),
                  "set_list_type error")
        XCTAssert(!code!.setListStart(3), "set_list_start error")
        XCTAssert(!fenced!.setListTight(false), "set_list_tight error")
        XCTAssert(!ordered_list!.setLiteral("content\n"),
                  "set_literal error")
        XCTAssert(!paragraph!.setFenceInfo("lang"),
                  "set_fence_info error")
        XCTAssert(!html!.setUrl("url"), "set_url error")
        XCTAssert(!heading!.setTitle("title"), "set_title error")
        
        XCTAssert(!heading!.setHeadingLevel(0),
                  "set_heading_level too small")
        XCTAssert(!heading!.setHeadingLevel(7),
                  "set_heading_level too large")
        XCTAssert(!bullet_list!.setListType(.noList),
                  "set_list_type invalid")
        XCTAssert(!bullet_list!.setListStart(-1),
                  "set_list_start negative")
        
        doc.free()
    }
    
    func testNodeCheck() {
        // Construct an incomplete tree.
        let doc = CmarkNode(.document)
        let p1 = CmarkNode(.paragraph)
        let p2 = CmarkNode(.paragraph)
        doc.firstChild = p1
        p1.next = p2
        
        XCTAssertEqual(doc.check(nil), 4, "node_check works")
        XCTAssertEqual(doc.check(nil), 0, "node_check fixes tree")
        
        doc.free()
    }
    
    func testIterator() {
        let doc = cmark_parse_document("> a *b*\n\nc", .default)
        var parnodes = 0
        let iter = CmarkIter(doc)
        
        while case let evType = iter.next(), evType != .done {
            let cur = iter.getNode()
            if cur?.type == .paragraph && evType == .enter {
                parnodes += 1
            }
        }
        XCTAssertEqual(parnodes, 2, "iterate correctly counts paragraphs")
        
        iter.free()
        doc.free()
    }
    
    func testIteratorDelete() {
        let md = """
            a *b* c
            
            * item1
            * item2
            
            a `b` c
            
            * item1
            * item2
            
            """
        let doc = cmark_parse_document(md, .default)
        let iter = CmarkIter(doc)
        
        while case let evType = iter.next(), evType != .done {
            let node = iter.getNode()!
            // Delete list, emph, and code nodes.
            if evType == .exit && node.type == .list ||
                evType == .exit && node.type == .emph ||
                evType == .enter && node.type == .code {
                node.free()
            }
        }
        
        let html = doc.renderHtml(.default)
        let expected = """
            <p>a  c</p>
            <p>a  c</p>

            """
        XCTAssertEqual(html, expected, "iterate and delete nodes")
        
        iter.free()
        doc.free()
    }
    
    func testCreateTree() {
        let doc = CmarkNode(type: .document)
        
        let p = CmarkNode(type: .paragraph)
        XCTAssert(!doc.insertBeforeMe(p), "insert before root fails")
        XCTAssert(!doc.insertAfterMe(p), "insert after root fails")
        XCTAssert(doc.append(child: p), "append1")
        XCTAssertEqual(doc.check(nil), 0, "append1 consistent")
        XCTAssert(p.parent === doc, "node_parent")
        
        let emph = CmarkNode(type: .emph)
        XCTAssert(p.prepend(child: emph), "prepend1")
        XCTAssertEqual(doc.check(nil), 0, "prepend1 consistent")
        
        let str1 = CmarkNode(type: .text)
        str1.setLiteral("Hello, ")
        XCTAssert(p.prepend(child: str1), "prepend2")
        XCTAssertEqual(doc.check(nil), 0, "prepend2 consistent")
        
        let str3 = CmarkNode(type: .text)
        str3.setLiteral("!")
        XCTAssert(p.append(child: str3), "append2")
        XCTAssertEqual(doc.check(nil), 0, "append2 consistent")
        
        let str2 = CmarkNode(type: .text)
        str2.setLiteral("world")
        XCTAssert(emph.append(child: str2), "append3")
        XCTAssertEqual(doc.check(nil), 0, "append3 consistent")
        
        let html = doc.renderHtml(.default)
        XCTAssertEqual(html, "<p>Hello, <em>world</em>!</p>\n", "render_html")
        
        XCTAssert(str1.insertBeforeMe(str3), "ins before1")
        XCTAssertEqual(doc.check(nil), 0, "ins before1 consistent")
        // 31e
        XCTAssert(p.firstChild === str3, "ins before1 works")
        
        XCTAssert(str1.insertBeforeMe(emph), "ins before2")
        XCTAssertEqual(doc.check(nil), 0, "ins before2 consistent")
        // 3e1
        XCTAssert(p.lastChild === str1, "ins before2 works")
        
        XCTAssert(str1.insertAfterMe(str3), "ins after1")
        XCTAssertEqual(doc.check(nil), 0, "ins after1 consistent")
        // e13
        XCTAssert(str1.next === str3, "ins after1 works")
        
        XCTAssert(str1.insertAfterMe(emph), "ins after2")
        XCTAssertEqual(doc.check(nil), 0, "ins after2 consistent")
        // 1e3
        XCTAssert(emph.prev === str1, "ins after2 works")
        
        let str4 = CmarkNode(type: .text)
        str4.setLiteral("brzz")
        XCTAssert(str1.replace(with: str4), "replace")
        // The replaced node is not freed
        str1.free()
        
        XCTAssertEqual(doc.check(nil), 0, "replace consistent")
        XCTAssert(emph.prev === str4, "replace works")
        XCTAssert(!p.replace(with: str4), "replace str for p fails")
        
        emph.unlink()
        
        let html2 = doc.renderHtml(.default)
        XCTAssertEqual(html2, "<p>brzz!</p>\n", "render_html after shuffling")
        
        doc.free()
        
        // TODO: Test that the contents of an unlinked inline are valid
        // after the parent block was destroyed. This doesn't work so far.
        emph.free()
    }
    
    func testCustomNodes() {
        let doc = CmarkNode(type: .document)
        let p = CmarkNode(type: .paragraph)
        doc.append(child: p)
        let ci = CmarkNode(type: .customInline)
        let str1 = CmarkNode(type: .text)
        str1.setLiteral("Hello")
        XCTAssert(ci.append(child: str1), "append1")
        XCTAssert(ci.setOnEnter("<ON ENTER|"), "set_on_enter")
        XCTAssert(ci.setOnExit("|ON EXIT>"), "set_on_exit")
        XCTAssertEqual(ci.getOnEnter(), "<ON ENTER|", "get_on_enter")
        XCTAssertEqual(ci.getOnExit(), "|ON EXIT>", "get_on_exit")
        p.append(child: ci)
        let cb = CmarkNode(type: .customBlock)
        cb.setOnEnter("<on enter|")
        // leave on_exit unset
        XCTAssertEqual(cb.getOnExit(), "", "get_on_exit (empty)")
        doc.append(child: cb)
        
        let html = doc.renderHtml(.default)
        XCTAssertEqual(html, "<p><ON ENTER|Hello|ON EXIT></p>\n<on enter|\n"
            , "render_html")
        
        let man = doc.renderMan(.default, 0)
        XCTAssertEqual(man, ".PP\n<ON ENTER|Hello|ON EXIT>\n<on enter|\n",
                       "render_man")
        
        doc.free()
    }
    
    func testHierarchy() {
        let bquote1 = CmarkNode(type: .blockQuote)
        let bquote2 = CmarkNode(type: .blockQuote)
        let bquote3 = CmarkNode(type: .blockQuote)
        
        XCTAssert(bquote1.append(child: bquote2), "append bquote2")
        XCTAssert(bquote2.append(child: bquote3), "append bquote3")
        XCTAssert(!bquote3.append(child: bquote3),
                  "adding a node as child of itself fails")
        XCTAssert(!bquote3.append(child: bquote1),
                  "adding a parent as child fails");
        
        bquote1.free()
        
        let maxNodeType = CmarkNodeType.lastBlock.rawValue > CmarkNodeType.lastInline.rawValue
            ? CmarkNodeType.lastBlock.rawValue
            : CmarkNodeType.lastInline.rawValue
        XCTAssert(maxNodeType < 32, "all node types < 32")
        
        let listItemFlag: UInt32 = 1 << CmarkNodeType.item.rawValue
        let b1: UInt32 = 1
        let topLevelBlocks: UInt32 = [
            CmarkNodeType.blockQuote, CmarkNodeType.list,
            CmarkNodeType.codeBlock, CmarkNodeType.htmlBlock,
            CmarkNodeType.paragraph, CmarkNodeType.heading,
            CmarkNodeType.thematicBreak].map{b1<<$0.rawValue}.reduce(0, |)
        let allInlines: UInt32 = [CmarkNodeType.text, CmarkNodeType.softbreak,
                                  CmarkNodeType.linebreak, CmarkNodeType.code,
                                  CmarkNodeType.htmlInline, CmarkNodeType.emph,
                                  CmarkNodeType.strong, CmarkNodeType.link,
                                  CmarkNodeType.image].map{b1<<$0.rawValue}.reduce(0, |)
        
        checkContent(.document, topLevelBlocks)
        checkContent(.blockQuote, topLevelBlocks)
        checkContent(.list, listItemFlag)
        checkContent(.item, topLevelBlocks)
        checkContent(.codeBlock, 0)
        checkContent(.htmlBlock, 0)
        checkContent(.paragraph, allInlines)
        checkContent(.heading, allInlines)
        checkContent(.thematicBreak, 0)
        checkContent(.text, 0)
        checkContent(.softbreak, 0)
        checkContent(.linebreak, 0)
        checkContent(.code, 0)
        checkContent(.htmlInline, 0)
        checkContent(.emph, allInlines)
        checkContent(.strong, allInlines)
        checkContent(.link, allInlines)
        checkContent(.image, allInlines)
    }
    
    private func checkContent(_ type: CmarkNodeType,
                              _ allowedContent: UInt32) {
        let node = CmarkNode(type: type)
        
        for childType in nodeTypes {
            let child = CmarkNode(type: childType)
            
            let got = node.append(child: child)
            let expected = ((allowedContent >> childType.rawValue) & 1) != 0
            
            XCTAssertEqual(got, expected, "add \(childType) as child of \(type)")
            
            child.free()
        }
        
        node.free()
    }
    
    func testParser() {
        checkMdToHtml("No newline", "<p>No newline</p>\n",
                      "document without trailing newline")
    }
    
    func testRenderHtml() {
        
        let markdown = """
        foo *bar*
        
        paragraph 2
        
        """
        let doc =
            cmark_parse_document(markdown, .default)
        
        let paragraph = doc.firstChild
        let html = paragraph?.renderHtml(.default)
        XCTAssertEqual(html, "<p>foo <em>bar</em></p>\n", "render single paragraph")
        
        let string = paragraph?.firstChild
        let html2 = string?.renderHtml(.default)
        XCTAssertEqual(html2, "foo ", "render single inline")
        
        let emph = string?.next
        let html3 = emph?.renderHtml(.default)
        XCTAssertEqual(html3, "<em>bar</em>", "render inline with children")
        
        doc.free()
    }
    
    func testRenderXml() {
        
        let markdown = """
        foo *bar*
        
        paragraph 2
        
        """
        let doc =
            cmark_parse_document(markdown, .default)
        
        let xml = doc.renderXml(.default)
        XCTAssertEqual(xml, """
          <?xml version=\"1.0\" encoding=\"UTF-8\"?>
          <!DOCTYPE document SYSTEM \"CommonMark.dtd\">
          <document xmlns=\"http://commonmark.org/xml/1.0\">
            <paragraph>
              <text>foo </text>
              <emph>
                <text>bar</text>
              </emph>
            </paragraph>
            <paragraph>
              <text>paragraph 2</text>
            </paragraph>
          </document>

          """,
                       "render document")
        let paragraph = doc.firstChild
        let xml2 = paragraph?.renderXml(.sourcepos)
        XCTAssertEqual(xml2, """
            <?xml version=\"1.0\" encoding=\"UTF-8\"?>
            <!DOCTYPE document SYSTEM \"CommonMark.dtd\">
            <paragraph sourcepos=\"1:1-1:9\">
              <text sourcepos=\"1:1-1:4\">foo </text>
              <emph sourcepos=\"1:5-1:9\">
                <text sourcepos=\"1:6-1:8\">bar</text>
              </emph>
            </paragraph>
            
            """,
                       "render first paragraph with source pos")
        doc.free()
    }
    
    func testRenderMan() {
        
        let markdown = """
            foo *bar*
            
            - Lorem ipsum dolor sit amet,
              consectetur adipiscing elit,
            - sed do eiusmod tempor incididunt
              ut labore et dolore magna aliqua.
            
            """
        let doc =
            cmark_parse_document(markdown, .default)
        
        let man = doc.renderMan(.default, 20)
        XCTAssertEqual(man, """
            .PP
            foo \\f[I]bar\\f[]
            .IP \\[bu] 2
            Lorem ipsum dolor
            sit amet,
            consectetur
            adipiscing elit,
            .IP \\[bu] 2
            sed do eiusmod
            tempor incididunt ut
            labore et dolore
            magna aliqua.
            
            """,
                       "render document with wrapping")
        let man2 = doc.renderMan(.default, 0)
        XCTAssertEqual(man2, """
            .PP
            foo \\f[I]bar\\f[]
            .IP \\[bu] 2
            Lorem ipsum dolor sit amet,
            consectetur adipiscing elit,
            .IP \\[bu] 2
            sed do eiusmod tempor incididunt
            ut labore et dolore magna aliqua.
            
            """,
                       "render document without wrapping")
        doc.free()
    }
    
    func testRenderLatex() {
        
        let markdown = """
            foo *bar* $%
            
            - Lorem ipsum dolor sit amet,
              consectetur adipiscing elit,
            - sed do eiusmod tempor incididunt
              ut labore et dolore magna aliqua.
            
            """
        let doc =
            cmark_parse_document(markdown, .default)
        
        let latex = doc.renderLatex(.default, 20)
        XCTAssertEqual(latex, """
            foo \\emph{bar} \\$\\%
            
            \\begin{itemize}
            \\item Lorem ipsum
            dolor sit amet,
            consectetur
            adipiscing elit,
            
            \\item sed do eiusmod
            tempor incididunt ut
            labore et dolore
            magna aliqua.
            
            \\end{itemize}
            
            """,
                       "render document with wrapping")
        let latex2 = doc.renderLatex(.default, 0)
        XCTAssertEqual(latex2, """
            foo \\emph{bar} \\$\\%
            
            \\begin{itemize}
            \\item Lorem ipsum dolor sit amet,
            consectetur adipiscing elit,
            
            \\item sed do eiusmod tempor incididunt
            ut labore et dolore magna aliqua.
            
            \\end{itemize}
            
            """,
                       "render document without wrapping")
        doc.free()
    }
    
    func testRenderCommonmark() {
        
        let markdown = """
            > \\- foo *bar* \\*bar\\*
            
            - Lorem ipsum dolor sit amet,
              consectetur adipiscing elit,
            - sed do eiusmod tempor incididunt
              ut labore et dolore magna aliqua.
            
            """
        let doc =
            cmark_parse_document(markdown, .default)
        
        let commonmark = doc.renderCommonmark(.default, 26)
        XCTAssertEqual(commonmark, """
            > \\- foo *bar* \\*bar\\*
            
              - Lorem ipsum dolor sit
                amet, consectetur
                adipiscing elit,
              - sed do eiusmod tempor
                incididunt ut labore
                et dolore magna
                aliqua.
            
            """,
                       "render document with wrapping")
        let commonmark2 = doc.renderCommonmark(.default, 0)
        XCTAssertEqual(commonmark2, """
            > \\- foo *bar* \\*bar\\*
            
              - Lorem ipsum dolor sit amet,
                consectetur adipiscing elit,
              - sed do eiusmod tempor incididunt
                ut labore et dolore magna aliqua.
            
            """,
                       "render document without wrapping")
        
        let text = CmarkNode(type: .text)
        text.setLiteral("Hi")
        let commonmark3 = text.renderCommonmark(.default, 0)
        XCTAssertEqual(commonmark3, "Hi\n", "render single inline node")
        
        text.free()
        doc.free()
    }
    
    func testUtf8() {
        // Ranges
        checkChar(true, [0x01], "valid utf8 01")
        checkChar(true, [0x7F], "valid utf8 7F")
        checkChar(false, [0x80], "invalid utf8 80")
        checkChar(false, [0xBF], "invalid utf8 BF")
        checkChar(false, [0xC0,0x80], "invalid utf8 C080")
        checkChar(false, [0xC1,0xBF], "invalid utf8 C1BF")
        checkChar(true, [0xC2,0x80], "valid utf8 C280")
        checkChar(true, [0xDF,0xBF], "valid utf8 DFBF")
        checkChar(false, [0xE0,0x80,0x80], "invalid utf8 E08080")
        checkChar(false, [0xE0,0x9F,0xBF], "invalid utf8 E09FBF")
        checkChar(true, [0xE0,0xA0,0x80], "valid utf8 E0A080")
        checkChar(true, [0xED,0x9F,0xBF], "valid utf8 ED9FBF")
        checkChar(false, [0xED,0xA0,0x80], "invalid utf8 EDA080")
        checkChar(false, [0xED,0xBF,0xBF], "invalid utf8 EDBFBF")
        checkChar(false, [0xF0,0x80,0x80,0x80], "invalid utf8 F0808080")
        checkChar(false, [0xF0,0x8F,0xBF,0xBF], "invalid utf8 F08FBFBF")
        checkChar(true, [0xF0,0x90,0x80,0x80], "valid utf8 F0908080")
        checkChar(true, [0xF4,0x8F,0xBF,0xBF], "valid utf8 F48FBFBF")
        checkChar(false, [0xF4,0x90,0x80,0x80], "invalid utf8 F4908080")
        checkChar(false, [0xF7,0xBF,0xBF,0xBF], "invalid utf8 F7BFBFBF")
        checkChar(false, [0xF8], "invalid utf8 F8")
        checkChar(false, [0xFF], "invalid utf8 FF")
        
        // Incomplete byte sequences at end of input
        checkIncompleteChar([0xE0,0xA0], "invalid utf8 E0A0")
        checkIncompleteChar([0xF0,0x90,0x80], "invalid utf8 F09080")
        
        // Invalid continuation bytes
        checkContinuationByte([0xC2,0x80])
        checkContinuationByte([0xE0,0xA0,0x80])
        checkContinuationByte([0xF0,0x90,0x80,0x80])
        
        // Test string containing null character
        let string_with_null = "((((\0))))\0".data(using: .utf8)!
        let html = cmark_markdown_to_html(
            string_with_null, .default)
        XCTAssertEqual(html, "<p>(((("+UTF8_REPL+"))))</p>\n", "utf8 with U+0000")
        
        // Test NUL followed by newline
        let string_with_nul_lf = "```\n\0\n```\n\0".data(using: .utf8)!
        let html2 = cmark_markdown_to_html(
            string_with_nul_lf, .default)
        XCTAssertEqual(html2, "<pre><code>"+UTF8_REPL+"\n</code></pre>\n",
                       "utf8 with \\0\\n")
    }
    
    private func checkChar(_ valid: Bool, _ utf8: [UInt8], _ msg: String) {
        var buf = Data()
        buf.append("((((".data(using: .utf8)!)
        buf.append(contentsOf: utf8)
        buf.append("))))\0".data(using: .utf8)!)
        
        if valid {
            let expected = "<p>(((("+String(bytes: utf8, encoding: .utf8)!+"))))</p>\n"
            checkMdToHtml(buf, expected, msg)
        } else {
            checkMdToHtml(buf, "<p>(((("+UTF8_REPL+"))))</p>\n", msg)
        }
    }
    
    private func checkIncompleteChar(_ utf8: [UInt8],
                                     _ msg: String) {
        var buf = Data()
        buf.append("----".data(using: .utf8)!)
        buf.append(contentsOf: utf8)
        buf.append(0)
        checkMdToHtml(buf, "<p>----"+UTF8_REPL+"</p>\n", msg)
    }
    
    private func checkContinuationByte(
        _ utf8: [UInt8]) {
        let len = utf8.count
        
        for pos in 1..<len {
            var buf = Data()
            buf.append("((((".data(using: .utf8)!)
            buf.append(contentsOf: utf8)
            buf.append("))))\0".data(using: .utf8)!)
            buf[4 + pos] = " "
            
            var expected = ""
            expected.append("<p>(((("+UTF8_REPL+" ")
            for _ in pos + 1 ..< len {
                expected.append(UTF8_REPL)
            }
            expected.append("))))</p>\n")
            
            let html =
                cmark_markdown_to_html(buf, .validateUTF8)
            XCTAssertEqual(html, expected, "invalid utf8 continuation byte \(pos)/\(len)")
        }
    }
    
    func testLineEndings() {
        // Test list with different line endings
        let list_with_endings = "- a\n- b\r\n- c\r- d\0".data(using: .utf8)!
        let html = cmark_markdown_to_html(
            list_with_endings, .default)
        XCTAssertEqual(html,
                       "<ul>\n<li>a</li>\n<li>b</li>\n<li>c</li>\n<li>d</li>\n</ul>\n",
                       "list with different line endings")
        
        let crlf_lines = "line\r\nline\r\n\0".data(using: .utf8)!
        let html2 = cmark_markdown_to_html(crlf_lines,
                                           [.default, .hardbreaks])
        XCTAssertEqual(html2, "<p>line<br />\nline</p>\n",
                       "crlf endings with CMARK_OPT_HARDBREAKS")
        let html3 = cmark_markdown_to_html(crlf_lines,
                                           [.default, .nobreaks])
        XCTAssertEqual(html3, "<p>line line</p>\n",
                       "crlf endings with CMARK_OPT_NOBREAKS")
        
        let no_line_ending = "```\nline\n```\0".data(using: .utf8)!
        let html4 = cmark_markdown_to_html(no_line_ending,
                                           .default)
        XCTAssertEqual(html4, "<pre><code>line\n</code></pre>\n",
                       "fenced code block with no final newline")
    }
    
    func testNumericEntities() {
        checkMdToHtml("&#0;", "<p>"+UTF8_REPL+"</p>\n",
                      "Invalid numeric entity 0")
        checkMdToHtml("&#55295;", "<p>\u{D7FF}</p>\n",
                      "Valid numeric entity 0xD7FF")
        checkMdToHtml("&#xD800;", "<p>"+UTF8_REPL+"</p>\n",
                      "Invalid numeric entity 0xD800")
        checkMdToHtml("&#xDFFF;", "<p>"+UTF8_REPL+"</p>\n",
                      "Invalid numeric entity 0xDFFF")
        checkMdToHtml("&#57344;", "<p>\u{E000}</p>\n",
                      "Valid numeric entity 0xE000")
        checkMdToHtml("&#x10FFFF;", "<p>\u{10FFFF}</p>\n",
                      "Valid numeric entity 0x10FFFF")
        checkMdToHtml("&#x110000;", "<p>"+UTF8_REPL+"</p>\n",
                      "Invalid numeric entity 0x110000")
        checkMdToHtml("&#x80000000;", "<p>"+UTF8_REPL+"</p>\n",
                      "Invalid numeric entity 0x80000000")
        checkMdToHtml("&#xFFFFFFFF;", "<p>"+UTF8_REPL+"</p>\n",
                      "Invalid numeric entity 0xFFFFFFFF")
        checkMdToHtml("&#99999999;", "<p>"+UTF8_REPL+"</p>\n",
                      "Invalid numeric entity 99999999")
        
        checkMdToHtml("&#;", "<p>&amp;#;</p>\n",
                      "Min decimal entity length")
        checkMdToHtml("&#x;", "<p>&amp;#x;</p>\n",
                      "Min hexadecimal entity length")
        checkMdToHtml("&#999999999;", "<p>&amp;#999999999;</p>\n",
                      "Max decimal entity length")
        checkMdToHtml("&#x000000041;", "<p>&amp;#x000000041;</p>\n",
                      "Max hexadecimal entity length")
    }
    
    func testSafe() {
        // Test safe mode
        let raw_html = """
            <div>\nhi\n</div>\n\n<a>hi</\
            a>\n[link](JAVAscript:alert('hi'))\n![image](\
            file:my.js)
            \0
            """.data(using: .utf8)!
        let html = cmark_markdown_to_html(raw_html,
                                          [.default, .safe])
        XCTAssertEqual(html, """
            <!-- raw HTML omitted -->\n<p><!-- raw HTML omitted \
            -->hi<!-- raw HTML omitted -->\n<a \
            href=\"\">link</a>\n<img src=\"\" alt=\"image\" \
            /></p>
            
            """,
                       "input with raw HTML and dangerous links")
    }
    
    private func checkMdToHtml(_ markdown: String,
                               _ expectedHtml: String, _ msg: String) {
        let html = cmark_markdown_to_html(markdown, .validateUTF8)
        XCTAssertEqual(html, expectedHtml, msg)
    }
    private func checkMdToHtml(_ markdownData: Data,
                               _ expectedHtml: String, _ msg: String) {
        let html = cmark_markdown_to_html(markdownData, .validateUTF8)
        XCTAssertEqual(html, expectedHtml, msg)
    }
    
    func testFeedAcrossLineEnding() {
        // See #117
        let parser = CmarkParser(options: .default)
        parser.feed("line1\r\0".data(using: .utf8)!)
        parser.feed("\nline2\r\n\0".data(using: .utf8)!)
        let document = parser.finish()
        XCTAssert(document.firstChild?.next == nil, "document has one paragraph")
        parser.free()
        document.free()
    }
    
    func testSourcePos() {
        let markdown = """
            # Hi *there*.
            
            Hello &ldquo; <http://www.google.com>
            there `hi` -- [okay](www.google.com (ok)).
            
            > 1. Okay.
            >    Sure.
            >
            > 2. Yes, okay.
            >    ![ok](hi \"yes\")
            
            """
        
        let doc = cmark_parse_document(markdown, .default)
        let xml = doc.renderXml([.default, .sourcepos])
        XCTAssertEqual(xml, """
            <?xml version=\"1.0\" encoding=\"UTF-8\"?>
            <!DOCTYPE document SYSTEM \"CommonMark.dtd\">
            <document sourcepos=\"1:1-10:20\" xmlns=\"http://commonmark.org/xml/1.0\">
              <heading sourcepos=\"1:1-1:13\" level=\"1\">
                <text sourcepos=\"1:3-1:5\">Hi </text>
                <emph sourcepos=\"1:6-1:12\">
                  <text sourcepos=\"1:7-1:11\">there</text>
                </emph>
                <text sourcepos=\"1:13-1:13\">.</text>
              </heading>
              <paragraph sourcepos=\"3:1-4:42\">
                <text sourcepos=\"3:1-3:14\">Hello “ </text>
                <link sourcepos=\"3:15-3:37\" destination=\"http://www.google.com\" title=\"\">
                  <text sourcepos=\"3:16-3:36\">http://www.google.com</text>
                </link>
                <softbreak />
                <text sourcepos=\"4:1-4:6\">there </text>
                <code sourcepos=\"4:8-4:9\">hi</code>
                <text sourcepos=\"4:11-4:14\"> -- </text>
                <link sourcepos=\"4:15-4:41\" destination=\"www.google.com\" title=\"ok\">
                  <text sourcepos=\"4:16-4:19\">okay</text>
                </link>
                <text sourcepos=\"4:42-4:42\">.</text>
              </paragraph>
              <block_quote sourcepos=\"6:1-10:20\">
                <list sourcepos=\"6:3-10:20\" type=\"ordered\" start=\"1\" delim=\"period\" tight=\"false\">
                  <item sourcepos=\"6:3-8:1\">
                    <paragraph sourcepos=\"6:6-7:10\">
                      <text sourcepos=\"6:6-6:10\">Okay.</text>
                      <softbreak />
                      <text sourcepos=\"7:6-7:10\">Sure.</text>
                    </paragraph>
                  </item>
                  <item sourcepos=\"9:3-10:20\">
                    <paragraph sourcepos=\"9:6-10:20\">
                      <text sourcepos=\"9:6-9:15\">Yes, okay.</text>
                      <softbreak />
                      <image sourcepos=\"10:6-10:20\" destination=\"hi\" title=\"yes\">
                        <text sourcepos=\"10:8-10:9\">ok</text>
                      </image>
                    </paragraph>
                  </item>
                </list>
              </block_quote>
            </document>
            
            """,
                       "sourcepos are as expected")
        doc.free()
    }
    
    func testRefSourcePos() {
        let markdown = """
            Let's try [reference] links.
            
            [reference]: https://github.com (GitHub)
            
            """
        
        let doc = cmark_parse_document(markdown, .default)
        let xml = doc.renderXml([.default, .sourcepos])
        XCTAssertEqual(xml, """
            <?xml version=\"1.0\" encoding=\"UTF-8\"?>
            <!DOCTYPE document SYSTEM \"CommonMark.dtd\">
            <document sourcepos=\"1:1-3:40\" xmlns=\"http://commonmark.org/xml/1.0\">
              <paragraph sourcepos=\"1:1-1:28\">
                <text sourcepos=\"1:1-1:10\">Let's try </text>
                <link sourcepos=\"1:11-1:21\" destination=\"https://github.com\" title=\"GitHub\">
                  <text sourcepos=\"1:12-1:20\">reference</text>
                </link>
                <text sourcepos=\"1:22-1:28\"> links.</text>
              </paragraph>
            </document>
            
            """,
                       "sourcepos are as expected")
        doc.free()
    }
    
    func testSpec() {
        let testBundle = Bundle(for: type(of: self))
        let specPath = testBundle.path(forResource: "spec", ofType: "txt")
        let st = SpecTests(spec: specPath!, normalize: false/*, number: 575*/)
        let result = st.run()
        XCTAssert(result.fail + result.error == 0, "SpecTests")
    }
    
    func testNormalize() {
        /*
         Based on doctests in normalize.py
         https://github.com/commonmark/cmark/blob/master/test/normalize.py
         */
        let tests: [(String, String)] = [
            ("<p>a  \t b</p>", "<p>a b</p>"),
            ("<p>a  \t\nb</p>", "<p>a b</p>"),
            ("<p>a  b</p>", "<p>a b</p>"),
            (" <p>a  b</p>", "<p>a b</p>"),
            ("<p>a  b</p> ", "<p>a b</p>"),
            ("\n\t<p>\n\t\ta  b\t\t</p>\n\t", "<p>a b</p>"),
            ("<i>a  b</i> ", "<i>a b</i> "),
            ("<br />", "<br>"),
            ("<a title=\"bar\" HREF=\"foo\">x</a>", "<a href=\"foo\" title=\"bar\">x</a>"),
            ("&forall;&amp;&gt;&lt;&quot;", "\u{2200}&amp;&gt;&lt;&quot;"),
            ("<a title=\"&forall;&amp;&gt;&lt;&quot;\">x</a>", "<a title=\"\u{2200}&amp;&gt;&lt;&quot;\">x</a>"),
            ]
        for (orig, expected) in tests {
            let actual = normalize_html(orig)
            XCTAssertEqual(expected, actual, orig)
        }
    }
    
    func testSmartPunct() {
        let testBundle = Bundle(for: type(of: self))
        let specPath = testBundle.path(forResource: "smart_punct", ofType: "txt")
        let st = SpecTests(spec: specPath!, normalize: false, options: .smart)
        let result = st.run()
        XCTAssert(result.fail + result.error == 0, "SmartPunct")
    }
    
    func testRegression() {
        let testBundle = Bundle(for: type(of: self))
        let specPath = testBundle.path(forResource: "regression", ofType: "txt")
        let st = SpecTests(spec: specPath!, normalize: false)
        let result = st.run()
        XCTAssert(result.fail + result.error == 0, "Regression")
    }
    
    func testRoundtrip() {
        let testBundle = Bundle(for: type(of: self))
        let specPath = testBundle.path(forResource: "spec", ofType: "txt")
        let st = RoundtripTests(spec: specPath!, normalize: true/*, number: 294*/)
        let result = st.run()
        XCTAssert(result.fail + result.error == 0, "RoundtripTests")
    }
    
    func testEntity() {
        let et = EntityTests(verbose: false)
        let (_, failed, errored) = et.run()
        XCTAssert(failed + errored == 0, "EntityTests")
    }
    
    func testPathological() {
        //### Some test cases take minitues to hours in the current implementation, better avoid...
        let pt = PathologicalTests(verbose: true, exclude: [/*"many references", "unclosed links A", "backticks"*/])
        let result = pt.run()
        XCTAssert(result.failed + result.errored == 0, "PathologicalTests")
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}

//Unicode REPLACEMENT CHARACTER
private let UTF8_REPL = "\u{FFFD}"

private let nodeTypes: [CmarkNodeType] = [
    .document, .blockQuote, .list,
    .item, .codeBlock, .htmlBlock,
    .paragraph, .heading, .thematicBreak,
    .text, .softbreak, .linebreak,
    .code, .htmlInline, .emph,
    .strong, .link, .image,
]
let numNodeTypes = nodeTypes.count

