//
//  Node.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/16.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on node.c and node.h
 https://github.com/commonmark/cmark/blob/master/src/node.c
 https://github.com/commonmark/cmark/blob/master/src/node.h
 
 Some comments moved from cmark.h
 https://github.com/commonmark/cmark/blob/master/src/cmark.h
 */

import Foundation

public struct CmarkList {
    var listType: CmarkListType = .noList
    var markerOffset: Int = 0
    var padding: Int = 0
    var start: Int = 0
    var delimiter: CmarkDelimType = .noDelim
    var bulletChar: UInt8 = 0
    var tight: Bool = false
}

public struct CmarkCode {
    var info: CmarkChunk = CmarkChunk()
    var literal: CmarkChunk = CmarkChunk()
    var fenceLength: Int = 0
    var fenceOffset: Int = 0
    var fenceChar: UInt8 = 0
    var fenced: Bool = false
}

public struct CmarkHeading {
    var level: Int = 0
    var setext: Bool = false
}

public struct CmarkLink {
    var url: CmarkChunk = CmarkChunk()
    var title: CmarkChunk = CmarkChunk()
}

public struct CmarkCustom {
    var onEnter: CmarkChunk = CmarkChunk()
    var onExit: CmarkChunk = CmarkChunk()
}

struct CmarkNodeInternalFlags: OptionSet {
    var rawValue: UInt16
    init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
    init(_ rawValue: UInt16) {
        self.rawValue = rawValue
    }
    static let open = CmarkNodeInternalFlags(1 << 0)
    static let lastLineBlank = CmarkNodeInternalFlags(1 << 1)
}

public class CmarkNode {
    let content: CmarkStrbuf
    
    /** Returns the next node in the sequence after 'node', or NULL if
     * there is none.
     */
    public internal(set) var next: CmarkNode? = nil
    
    /** Returns the previous node in the sequence after 'node', or NULL if
     * there is none.
     */
    public internal(set) weak var prev: CmarkNode? = nil
    
    /** Returns the parent of 'node', or NULL if there is none.
     */
    public internal(set) weak var parent: CmarkNode? = nil
    
    /** Returns the first child of 'node', or NULL if 'node' has no children.
     */
    public internal(set) var firstChild: CmarkNode? = nil
    
    /** Returns the last child of 'node', or NULL if 'node' has no children.
     */
    public internal(set) weak var lastChild: CmarkNode? = nil
    
    //### Do not use user_data, the property will be removed
    /** Returns the user data of 'node'.
     */
    /** Sets arbitrary user data for 'node'.  Returns 1 on success,
     * 0 on failure.
     */
    public var userData: UnsafeRawPointer? = nil
    
    public var userInfo: [String: Any] = [:]
    
    /** Returns the line on which 'node' begins.
     */
    public internal(set) var startLine: Int = 0
    
    /** Returns the column at which 'node' begins.
     */
    public internal(set) var startColumn: Int = 0
    
    /** Returns the line on which 'node' ends.
     */
    public internal(set) var endLine: Int = 0
    
    /** Returns the column at which 'node' ends.
     */
    public internal(set) var endColumn: Int = 0
    var internalOffset: Int = 0
    
    /** Returns the type of 'node', or `CMARK_NODE_NONE` on error.
     */
    public internal(set) var type: CmarkNodeType
    
    var flags: CmarkNodeInternalFlags
    
    var asType: AsType
    
    enum AsType {
        case literal(CmarkChunk)
        case list(CmarkList)
        case code(CmarkCode)
        case heading(CmarkHeading)
        case link(CmarkLink)
        case custom(CmarkCustom)
        case htmlBlockType(Int)
    }
    
    public var asCode: CmarkCode? {
        if case .code(let code) = asType {
            return code
        } else {
            return nil
        }
    }
    public var asHeading: CmarkHeading? {
        if case .heading(let heading) = asType {
            return heading
        } else {
            return nil
        }
    }
    public var asLiteral: CmarkChunk? {
        if case .literal(let literal) = asType {
            return literal
        } else {
            return nil
        }
    }
    public var asLink: CmarkLink? {
        if case .link(let link) = asType {
            return link
        } else {
            return nil
        }
    }
    public var asCustom: CmarkCustom? {
        if case .custom(let custom) = asType {
            return custom
        } else {
            return nil
        }
    }
    public var asList: CmarkList? {
        if case .list(let list) = asType {
            return list
        } else {
            return nil
        }
    }
    public var asHtmlBlockType: Int? {
        if case .htmlBlockType(let htmlBlockType) = asType {
            return htmlBlockType
        } else {
            return nil
        }
    }
    
    init(tag: CmarkNodeType, content: CmarkStrbuf, flags: CmarkNodeInternalFlags) {
        self.content = content
        type = tag
        self.flags = flags
        asType = AsType.htmlBlockType(0)
    }
}

extension CmarkNode {
    
    private func S_is_block() -> Bool {
        return self.type.isBlock
    }
    
    private func S_is_inline() -> Bool {
        return self.type.isInline
    }
    
    private func canContain(_ child: CmarkNode?) -> Bool {
        
        guard let child = child else {
            return false
        }
        
        // Verify that child is not an ancestor of node or equal to node.
        var cur: CmarkNode? = self
        repeat {
            if cur === child {
                return false
            }
            cur = cur!.parent
        } while cur != nil
        
        if child.type == .document {
            return false
        }
        
        switch self.type {
        case .document,
             .blockQuote,
             .item:
            return child.S_is_block() && child.type != .item
            
        case .list:
            return child.type == .item
            
        case .customBlock:
            return true;
            
        case .paragraph,
             .heading,
             .emph,
             .strong,
             .link,
             .image,
             .customInline:
            return child.S_is_inline()
            
        default:
            break
        }
        
        return false
    }
    
    /**
     * ## Creating and Destroying Nodes
     */
    
    /** Same as `cmark_node_new`, but explicitly listing the memory
     * allocator used to allocate the node.  Note:  be sure to use the same
     * allocator for every node in a tree, or bad things can happen.
     */
    //### Swift version of cmark does not provide customization feature for memory allocation.
    //### Always use `init(type:)`.
    convenience init(_ type: CmarkNodeType) {
        self.init(simple: type)
        
        switch type {
        case .heading:
            let heading = CmarkHeading(level: 1, setext: false)
            asType = .heading(heading)
            
        case .list:
            let list = CmarkList(listType: .bulletList, markerOffset: 0, padding: 0, start: 0, delimiter: .noDelim, bulletChar: 0, tight: false)
            asType = .list(list)
            
        default:
            break
        }
        
    }
    
    /** Creates a new node of type 'type'.  Note that the node may have
     * other required properties, which it is the caller's responsibility
     * to assign.
     */
    public convenience init(type: CmarkNodeType) {
        self.init(type)
    }
    
    // Free a cmark_node list and any children.
    private func S_free_nodes() {
        var curr: CmarkNode? = self
        while let e = curr {
            e.content.free()
            switch e.type {
            case .codeBlock:
                e.asCode?.info.free()
                e.asCode?.literal.free()
            case .text,
                 .htmlInline,
                 .code,
                 .htmlBlock:
                e.asLiteral?.free()
            case .link,
                 .image:
                e.asLink?.url.free()
                e.asLink?.title.free()
            case .customBlock,
                 .customInline:
                e.asCustom?.onEnter.free()
                e.asCustom?.onExit.free()
            default:
                break
            }
            if let lastChild = e.lastChild {
                // Splice children into list
                lastChild.next = e.next
                e.next = e.firstChild
            }
            let next = e.next
            curr = next
        }
    }
    
    /** Frees the memory allocated for a node and any children.
     */
    public func free() {
        S_node_unlink()
        next = nil
        S_free_nodes()
    }
    
    /**
     * ## Accessors
     */
    
    //### Use `type` property
    //cmark_node_type cmark_node_get_type(cmark_node *node) {
    //  if (node == NULL) {
    //    return CMARK_NODE_NONE;
    //  } else {
    //    return (cmark_node_type)node->type;
    //  }
    //}
    
    /** Like 'cmark_node_get_type', but returns a string representation
     of the type, or `"<unknown>"`.
     */
    func getTypeString() -> String {
        
        switch type {
        case .none:
            return "none"
        case .document:
            return "document"
        case .blockQuote:
            return "block_quote"
        case .list:
            return "list"
        case .item:
            return "item"
        case .codeBlock:
            return "code_block"
        case .htmlBlock:
            return "html_block"
        case .customBlock:
            return "custom_block"
        case .paragraph:
            return "paragraph"
        case .heading:
            return "heading"
        case .thematicBreak:
            return "thematic_break"
        case .text:
            return "text"
        case .softbreak:
            return "softbreak"
        case .linebreak:
            return "linebreak"
        case .code:
            return "code"
        case .htmlInline:
            return "html_inline"
        case .customInline:
            return "custom_inline"
        case .emph:
            return "emph"
        case .strong:
            return "strong"
        case .link:
            return "link"
        case .image:
            return "image"
        }
        
    }
    
    /**
     * ## Tree Traversal
     */
    
    //### Use `next` property
    //cmark_node *cmark_node_next(cmark_node *node) {
    //  if (node == NULL) {
    //    return NULL;
    //  } else {
    //    return node->next;
    //  }
    //}
    
    //### Use `prev` property
    //cmark_node *cmark_node_previous(cmark_node *node) {
    //  if (node == NULL) {
    //    return NULL;
    //  } else {
    //    return node->prev;
    //  }
    
    //### Use `parent` property
    //cmark_node *cmark_node_parent(cmark_node *node) {
    //  if (node == NULL) {
    //    return NULL;
    //  } else {
    //    return node->parent;
    //  }
    //}
    
    //### Use `firstChild` property
    //cmark_node *cmark_node_first_child(cmark_node *node) {
    //  if (node == NULL) {
    //    return NULL;
    //  } else {
    //    return node->first_child;
    //  }
    //}
    
    //### Use `lastChild` property
    //cmark_node *cmark_node_last_child(cmark_node *node) {
    //  if (node == NULL) {
    //    return NULL;
    //  } else {
    //    return node->last_child;
    //  }
    //}
    
    //### Do not use user_data, the property will be removed
    //void *cmark_node_get_user_data(cmark_node *node) {
    //  if (node == NULL) {
    //    return NULL;
    //  } else {
    //    return node->user_data;
    //  }
    //}
    
    //### Do not use user_data, the property will be removed
    //int cmark_node_set_user_data(cmark_node *node, void *user_data) {
    //  if (node == NULL) {
    //    return 0;
    //  }
    //  node->user_data = user_data;
    //  return 1;
    //}
    
    /** Returns the string contents of 'node', or an empty
     string if none is set.  Returns NULL if called on a
     node that does not have string content.
     */
    public func getLiteral() -> String? {
        
        switch type {
        case .htmlBlock, .text, .htmlInline, .code:
            return asLiteral?.toString()
            
        case .codeBlock:
            return asCode?.literal.toString()
            
        default:
            break
        }
        
        return nil
    }
    
    /** Sets the string contents of 'node'.  Returns 1 on success,
     * 0 on failure.
     */
    @discardableResult
    public func setLiteral(_ content: String) -> Bool {
        
        switch type {
        case .htmlBlock, .text, .htmlInline, .code:
            asType = .literal(CmarkChunk(literal: content))
            return true
            
        case .codeBlock:
            var code = asCode ?? CmarkCode()
            code.literal = CmarkChunk(literal: content)
            asType = .code(code)
            return true
            
        default:
            break
        }
        
        return false
    }
    
    /** Returns the heading level of 'node', or 0 if 'node' is not a heading.
     */
    public func getHeadingLevel() -> Int {
        
        return asHeading?.level ?? 0
    }
    
    /** Sets the heading level of 'node', returning 1 on success and 0 on error.
     */
    public func setHeadingLevel(_ level: Int) -> Bool {
        if level < 1 || level > 6 {
            return false
        }
        
        switch type {
        case .heading:
            var heading = asHeading ?? CmarkHeading()
            heading.level = level
            asType = .heading(heading)
            return true
            
        default:
            break
        }
        
        return false
    }
    
    /** Returns the list type of 'node', or `CMARK_NO_LIST` if 'node'
     * is not a list.
     */
    public func getListType() -> CmarkListType {
        return asList?.listType ?? .noList
    }
    
    /** Sets the list type of 'node', returning 1 on success and 0 on error.
     */
    public func setListType(_ type: CmarkListType) -> Bool {
        guard type == .bulletList || type == .orderedList else {
            return false
        }
        
        if self.type == .list {
            var list = asList ?? CmarkList()
            list.listType = type
            asType = .list(list)
            return true
        } else {
            return false
        }
    }
    
    /** Returns the list delimiter type of 'node', or `CMARK_NO_DELIM` if 'node'
     * is not a list.
     */
    public func getListDelim() -> CmarkDelimType {
        
        return asList?.delimiter ?? .noDelim
    }
    
    /** Sets the list delimiter type of 'node', returning 1 on success and 0
     * on error.
     */
    public func setListDelim(_ delim: CmarkDelimType) -> Bool {
        guard delim == .periodDelim || delim == .parenDelim else {
            return false
        }
        
        if type == .list {
            var list = asList ?? CmarkList()
            list.delimiter = delim
            asType = .list(list)
            return true
        } else {
            return false
        }
    }
    
    /** Returns starting number of 'node', if it is an ordered list, otherwise 0.
     */
    public func getListStart() -> Int {
        
        return asList?.start ?? 0
    }
    
    /** Sets starting number of 'node', if it is an ordered list. Returns 1
     * on success, 0 on failure.
     */
    public func setListStart(_ start: Int) -> Bool {
        if start < 0 {
            return false
        }
        
        if type == .list {
            var list = asList ?? CmarkList()
            list.start = start
            asType = .list(list)
            return true
        } else {
            return false
        }
    }
    
    /** Returns 1 if 'node' is a tight list, 0 otherwise.
     */
    public func getListTight() -> Bool {
        
        return asList?.tight ?? false
    }
    
    /** Sets the "tightness" of a list.  Returns 1 on success, 0 on failure.
     */
    public func setListTight(_ tight: Bool) -> Bool {
        
        if type == .list {
            var list = asList ?? CmarkList()
            list.tight = tight
            asType = .list(list)
            return true
        } else {
            return false
        }
    }
    
    /** Returns the info string from a fenced code block.
     */
    public func getFenceInfo() -> String? {
        
        return asCode?.info.toString()
    }
    
    /** Sets the info string in a fenced code block, returning 1 on
     * success and 0 on failure.
     */
    public func setFenceInfo(_ info: String) -> Bool {
        
        if type == .codeBlock {
            let code = asCode ?? CmarkCode()
            code.info.setCstr(info)
            asType = .code(code)
            return true
        } else {
            return false
        }
    }
    
    /** Returns the URL of a link or image 'node', or an empty string
     if no URL is set.  Returns NULL if called on a node that is
     not a link or image.
     */
    public func getUrl() -> String? {
        
        return asLink?.url.toString()
    }
    
    /** Sets the URL of a link or image 'node'. Returns 1 on success,
     * 0 on failure.
     */
    public func setUrl(_ url: String) -> Bool {
        
        switch type {
        case .link, .image:
            let link = asLink ?? CmarkLink()
            link.url.setCstr(url)
            asType = .link(link)
            return true
        default:
            break
        }
        
        return false
    }
    
    /** Returns the title of a link or image 'node', or an empty
     string if no title is set.  Returns NULL if called on a node
     that is not a link or image.
     */
    public func getTitle() -> String? {
        
        return asLink?.title.toString()
    }
    
    /** Sets the title of a link or image 'node'. Returns 1 on success,
     * 0 on failure.
     */
    public func setTitle(_ title: String) -> Bool {
        
        switch type {
        case .link, .image:
            let link = asLink ?? CmarkLink()
            link.title.setCstr(title)
            asType = .link(link)
            return true
        default:
            break
        }
        
        return false
    }
    
    /** Returns the literal "on enter" text for a custom 'node', or
     an empty string if no on_enter is set.  Returns NULL if called
     on a non-custom node.
     */
    public func getOnEnter() -> String? {
        
        return asCustom?.onEnter.toString()
    }
    
    /** Sets the literal text to render "on enter" for a custom 'node'.
     Any children of the node will be rendered after this text.
     Returns 1 on success 0 on failure.
     */
    @discardableResult
    public func setOnEnter(_ onEnter: String) -> Bool {
        
        switch type {
        case .customInline, .customBlock:
            let custom = asCustom ?? CmarkCustom()
            custom.onEnter.setCstr(onEnter)
            asType = .custom(custom)
            return true
        default:
            break
        }
        
        return false
    }
    
    /** Returns the literal "on exit" text for a custom 'node', or
     an empty string if no on_exit is set.  Returns NULL if
     called on a non-custom node.
     */
    public func getOnExit() -> String? {
        
        return asCustom?.onExit.toString()
    }
    
    /** Sets the literal text to render "on exit" for a custom 'node'.
     Any children of the node will be rendered before this text.
     Returns 1 on success 0 on failure.
     */
    @discardableResult
    public func setOnExit(_ onExit: String) -> Bool {
        
        switch type {
        case .customInline, .customBlock:
            let custom = asCustom ?? CmarkCustom()
            custom.onExit.setCstr(onExit)
            asType = .custom(custom)
            return true
        default:
            break
        }
        
        return false
    }
    
    //### User `startLine` property
    //int cmark_node_get_start_line(cmark_node *node) {
    //  if (node == NULL) {
    //    return 0;
    //  }
    //  return node->start_line;
    //}
    
    //### User `startColumn` property
    //int cmark_node_get_start_column(cmark_node *node) {
    //  if (node == NULL) {
    //    return 0;
    //  }
    //  return node->start_column;
    //}
    
    //### User `endLine` property
    //int cmark_node_get_end_line(cmark_node *node) {
    //  if (node == NULL) {
    //    return 0;
    //  }
    //  return node->end_line;
    //}
    
    //### User `endColumn` property
    //int cmark_node_get_end_column(cmark_node *node) {
    //  if (node == NULL) {
    //    return 0;
    //  }
    //  return node->end_column;
    //}
    
    /**
     * ## Tree Manipulation
     */
    
    // Unlink a node without adjusting its next, prev, and parent pointers.
    private func S_node_unlink() {
        
        if let prev = self.prev {
            prev.next = self.next
        }
        if let next = self.next {
            next.prev = self.prev
        }
        
        // Adjust first_child and last_child of parent.
        if let parent = self.parent {
            if parent.firstChild === self {
                parent.firstChild = self.next
            }
            if parent.lastChild === self {
                parent.lastChild = self.prev
            }
        }
    }
    
    /** Unlinks a 'node', removing it from the tree, but not freeing its
     * memory.  (Use 'cmark_node_free' for that.)
     */
    public func unlink() {
        S_node_unlink()
        
        next = nil
        prev = nil
        parent = nil
    }
    
    /** Inserts 'sibling' before 'node'.  Returns 1 on success, 0 on failure.
     */
    @discardableResult
    public func insertBeforeMe(_ sibling: CmarkNode?) -> Bool {
        guard let sibling = sibling else {
            return false
        }
        
        guard let parent = self.parent, parent.canContain(sibling) else {
            return false
        }
        
        sibling.S_node_unlink()
        
        let oldPrev = self.prev
        
        // Insert 'sibling' between 'old_prev' and 'node'.
        if let oldPrev = oldPrev {
            oldPrev.next = sibling
        }
        sibling.prev = oldPrev
        sibling.next = self
        prev = sibling
        
        // Set new parent.
        sibling.parent = parent
        
        // Adjust first_child of parent if inserted as first child.
        if oldPrev == nil {
            parent.firstChild = sibling
        }
        
        return true
    }
    
    /** Inserts 'sibling' after 'node'. Returns 1 on success, 0 on failure.
     */
    @discardableResult
    func insertAfterMe(_ sibling: CmarkNode?) -> Bool {
        guard let sibling = sibling else {
            return false
        }
        
        guard let parent = parent, parent.canContain(sibling) else {
            return false
        }
        
        sibling.S_node_unlink()
        
        let oldNext = self.next
        
        // Insert 'sibling' between 'node' and 'old_next'.
        if let oldNext = oldNext {
            oldNext.prev = sibling
        }
        sibling.next = oldNext
        sibling.prev = self
        self.next = sibling
        
        // Set new parent.
        sibling.parent = parent
        
        // Adjust last_child of parent if inserted as last child.
        if oldNext == nil {
            parent.lastChild = sibling
        }
        
        return true
    }
    
    /** Replaces 'oldnode' with 'newnode' and unlinks 'oldnode' (but does
     * not free its memory).
     * Returns 1 on success, 0 on failure.
     */
    public func replace(with newnode: CmarkNode) -> Bool {
        if !insertBeforeMe(newnode) {
            return false
        }
        unlink()
        return true
    }
    
    /** Adds 'child' to the beginning of the children of 'node'.
     * Returns 1 on success, 0 on failure.
     */
    public func prepend(child: CmarkNode) -> Bool {
        if !canContain(child) {
            return false
        }
        
        child.S_node_unlink()
        
        let oldFirstChild = firstChild
        
        child.next = oldFirstChild
        child.prev = nil
        child.parent = self
        firstChild = child
        
        if let oldFirstChild = oldFirstChild {
            oldFirstChild.prev = child
        } else {
            // Also set last_child if node previously had no children.
            lastChild = child
        }
        
        return true
    }
    
    /** Adds 'child' to the end of the children of 'node'.
     * Returns 1 on success, 0 on failure.
     */
    @discardableResult
    func append(child: CmarkNode) -> Bool {
        if !self.canContain(child) {
            return false
        }
        
        child.S_node_unlink()
        
        let oldLastChild = self.lastChild
        
        child.next = nil
        child.prev = oldLastChild
        child.parent = self
        self.lastChild = child
        
        if let oldLastChild = oldLastChild {
            oldLastChild.next = child
        } else {
            // Also set first_child if node previously had no children.
            self.firstChild = child
        }
        
        return true
    }
    
    private func S_print_error(_ out: UnsafeMutablePointer<FILE>!, _ elem: String) {
        if out == nil {
            return
        }
        fputs("Invalid '\(getTypeString())' in node type %s at \(startLine):\(startColumn)", out)
    }
    
    func check(_ out: UnsafeMutablePointer<FILE>!) -> Int {
        var errors = 0
        
        var cur: CmarkNode? = self
        outer: while true {
            if let firstChild = cur?.firstChild {
                if firstChild.prev != nil {
                    firstChild.S_print_error(out, "prev")
                    firstChild.prev = nil
                    errors += 1
                }
                if firstChild.parent !== cur {
                    firstChild.S_print_error(out, "parent")
                    firstChild.parent = cur
                    errors += 1
                }
                cur = firstChild
                continue
            }
            
            next_sibling: while true {
                if cur === self {
                    break outer
                }
                if let next = cur?.next {
                    if next.prev !== cur {
                        next.S_print_error(out, "prev")
                        next.prev = cur
                        errors += 1
                    }
                    if next.parent !== cur?.parent {
                        next.S_print_error(out, "parent")
                        next.parent = cur?.parent
                        errors += 1
                    }
                    cur = next
                    continue outer
                }
                
                if cur?.parent?.lastChild !== cur {
                    cur?.parent?.S_print_error(out, "last_child")
                    cur?.parent?.lastChild = cur
                    errors += 1
                }
                cur = cur?.parent
            }
        }
        
        return errors
    }
}

