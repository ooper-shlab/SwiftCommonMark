//
//  Iterator.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/17.
//  Copyright © 2017 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on iterator.c and iterator.h
 https://github.com/commonmark/cmark/blob/master/src/iterator.c
 https://github.com/commonmark/cmark/blob/master/src/iterator.h
 
 Some comments and a type moved from cmark.h
 https://github.com/commonmark/cmark/blob/master/src/cmark.h
 */

import Foundation

/**
 * ## Iterator
 *
 * An iterator will walk through a tree of nodes, starting from a root
 * node, returning one node at a time, together with information about
 * whether the node is being entered or exited.  The iterator will
 * first descend to a child node, if there is one.  When there is no
 * child, the iterator will go to the next sibling.  When there is no
 * next sibling, the iterator will return to the parent (but with
 * a 'cmark_event_type' of `CMARK_EVENT_EXIT`).  The iterator will
 * return `CMARK_EVENT_DONE` when it reaches the root node again.
 * One natural application is an HTML renderer, where an `ENTER` event
 * outputs an open tag and an `EXIT` event outputs a close tag.
 * An iterator might also be used to transform an AST in some systematic
 * way, for example, turning all level-3 headings into regular paragraphs.
 *
 *     void
 *     usage_example(cmark_node *root) {
 *         cmark_event_type ev_type;
 *         cmark_iter *iter = cmark_iter_new(root);
 *
 *         while ((ev_type = cmark_iter_next(iter)) != CMARK_EVENT_DONE) {
 *             cmark_node *cur = cmark_iter_get_node(iter);
 *             // Do something with `cur` and `ev_type`
 *         }
 *
 *         cmark_iter_free(iter);
 *     }
 *
 * Iterators will never return `EXIT` events for leaf nodes, which are nodes
 * of type:
 *
 * * CMARK_NODE_HTML_BLOCK
 * * CMARK_NODE_THEMATIC_BREAK
 * * CMARK_NODE_CODE_BLOCK
 * * CMARK_NODE_TEXT
 * * CMARK_NODE_SOFTBREAK
 * * CMARK_NODE_LINEBREAK
 * * CMARK_NODE_CODE
 * * CMARK_NODE_HTML_INLINE
 *
 * Nodes must only be modified after an `EXIT` event, or an `ENTER` event for
 * leaf nodes.
 */

public enum CmarkEventType {
    case none
    case done
    case enter
    case exit
}

struct CmarkIterState {
    var evType: CmarkEventType = .none
    var node: CmarkNode?
}

public class CmarkIter {
    
    /** Returns the root node.
     */
    private(set) public var root: CmarkNode
    
    private var cur: CmarkIterState = CmarkIterState()
    private var nextState: CmarkIterState = CmarkIterState()
    
    fileprivate static let S_leaf_mask: Int = ([
        .htmlBlock, .thematicBreak,
        .codeBlock, .text,
        .softbreak, .linebreak,
        .code, .htmlInline] as [CmarkNodeType]).reduce(0) {$0 | (1 << Int($1.rawValue))}
    
    /** Creates a new iterator starting at 'root'.  The current node and event
     * type are undefined until 'cmark_iter_next' is called for the first time.
     * The memory allocated for the iterator should be released using
     * 'cmark_iter_free' when it is no longer needed.
     */
    public init(_ root: CmarkNode) {
        self.root = root
        self.cur.evType = .none
        self.cur.node = nil
        self.nextState.evType = .enter
        self.nextState.node = root
    }
    
    /** Frees the memory allocated for an iterator.
     */
    public func free() {}
}

private extension CmarkNode {
    var isLeaf: Bool {
        return ((1 << Int(self.type.rawValue)) & CmarkIter.S_leaf_mask) != 0
    }
}

extension CmarkIter {
    
    /** Advances to the next node and returns the event type (`CMARK_EVENT_ENTER`,
     * `CMARK_EVENT_EXIT` or `CMARK_EVENT_DONE`).
     */
    public func next() -> CmarkEventType {
        let evType = self.nextState.evType
        let node = self.nextState.node
        
        self.cur.evType = evType
        self.cur.node = node
        
        if evType == .done {
            return evType
        }
        
        /* roll forward to next item, setting both fields */
        if evType == .enter && !node!.isLeaf {
            if node!.firstChild == nil {
                /* stay on this node but exit */
                self.nextState.evType = .exit
            } else {
                self.nextState.evType = .enter
                self.nextState.node = node!.firstChild
            }
        } else if node === self.root {
            /* don't move past root */
            self.nextState.evType = .done
            self.nextState.node = nil
        } else if let next = node?.next {
            self.nextState.evType = .enter
            self.nextState.node = next
        } else if let parent = node?.parent {
            self.nextState.evType = .exit
            self.nextState.node = parent
        } else {
            assert(false)
            self.nextState.evType = .done
            self.nextState.node = nil
        }
        
        return evType
    }
    
    /** Resets the iterator so that the current node is 'current' and
     * the event type is 'event_type'.  The new current node must be a
     * descendant of the root node or the root node itself.
     */
    public func reset(_ current: CmarkNode,
                      _ eventType: CmarkEventType) {
        self.nextState.evType = eventType
        self.nextState.node = current
        _ = next()
    }
    
    /** Returns the current node.
     */
    public func getNode() -> CmarkNode? {return self.cur.node}
}
//
//### Not used internally... Do you need this to be public?
///** Returns the current event type.
// */
//cmark_event_type cmark_iter_get_event_type(cmark_iter *iter) {
//  return iter->cur.ev_type;
//}
//
//### Use `root` property
//cmark_node *cmark_iter_get_root(cmark_iter *iter) { return iter->root; }

extension CmarkNode {
    
    /** Consolidates adjacent text nodes.
     */
    public func consolidateTextNodes() {
        let iter = CmarkIter(self)
        let buf = CmarkStrbuf()
        
        while case let evType = iter.next(), evType != .done {
            let cur = iter.getNode()
            if evType == .enter, let cur = cur, cur.type == .text,
                let next = cur.next, next.type == .text {
                buf.clear()
                buf.put(cur.asLiteral!)
                var tmp: CmarkNode? = next
                while let temp = tmp, temp.type == .text {
                    _ = iter.next()
                    buf.put(temp.asLiteral!)
                    cur.endColumn = temp.endColumn
                    let next = temp.next
                    temp.free()
                    tmp = next
                }
                cur.asLiteral?.free()
                cur.asType = .literal(buf.bufDetach())
            }
        }
        
        buf.free()
        iter.free()
    }
}
