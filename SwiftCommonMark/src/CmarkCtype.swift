//
//  CmarkCtype.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/17.
//  Copyright © 2017−2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on cmark_ctype.c and cmark_ctype.h
 https://github.com/commonmark/cmark/blob/master/src/cmark_ctype.c
 https://github.com/commonmark/cmark/blob/master/src/cmark_ctype.h
 */

import Foundation

/** 1 = space, 2 = punct, 3 = digit, 4 = alpha, 0 = other
 */
private let cmark_ctype_class: [UInt8] = [
    /*      0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f */
    /* 0 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0,
    /* 1 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    /* 2 */ 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    /* 3 */ 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 2, 2, 2, 2, 2, 2,
    /* 4 */ 2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
    /* 5 */ 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 2, 2, 2, 2, 2,
    /* 6 */ 2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
    /* 7 */ 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 2, 2, 2, 2, 0]

private func isAscii(_ c: Int32) -> Bool {
    return 0x00 <= c && c <= 0x7F
}

/** Locale-independent versions of functions from ctype.h.
 * We want cmark to behave the same no matter what the system locale.
 */

/**
 * Returns 1 if c is a "whitespace" character as defined by the spec.
 */
func cmark_isspace(_ c: Int32) -> Bool {return isAscii(c) && cmark_ctype_class[Int(c)] == 1}

/**
 * Returns 1 if c is an ascii punctuation character.
 */
func cmark_ispunct(_ c: Int32) -> Bool {return isAscii(c) && cmark_ctype_class[Int(c)] == 2}

func cmark_isalnum(_ c: Int32) -> Bool {
    if !isAscii(c) {return false}
    let result = cmark_ctype_class[Int(c)]
    return result == 3 || result == 4
}

func cmark_isdigit(_ c: Int32) -> Bool {return isAscii(c) && cmark_ctype_class[Int(c)] == 3}

func cmark_isalpha(_ c: Int32) -> Bool {return isAscii(c) && cmark_ctype_class[Int(c)] == 4}

extension UInt8 {
    var isSpace: Bool {return cmark_isspace(Int32(self))}
    var isPunct: Bool {return cmark_ispunct(Int32(self))}
    var isAlnum: Bool {return cmark_isalnum(Int32(self))}
    var isDigit: Bool {return cmark_isdigit(Int32(self))}
    var isAlpha: Bool {return cmark_isalpha(Int32(self))}
}

extension UnicodeScalar {
    var isSpace: Bool {return cmark_isspace(Int32(self.value))}
    var isPunct: Bool {return cmark_ispunct(Int32(self.value))}
    var isAlnum: Bool {return cmark_isalnum(Int32(self.value))}
    var isDigit: Bool {return cmark_isdigit(Int32(self.value))}
    var isAlpha: Bool {return cmark_isalpha(Int32(self.value))}
}
